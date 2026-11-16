extends Node
## Headless balance simulator. Plays thousands of battles and whole runs with a
## simple AI, using the real card resources, enemy scenes and run constants.
##
## Run from the project folder:
##   godot --headless --path . res://tools/balance_sim.tscn
## Options (after `--`):
##   --n=2000          battles per test (runs use n / 2)
##   --sharpness=0 --guard=0 --adrenaline=0 --hp_bonus=0   skill-tree levels' bonuses
##   --seed=1          RNG seed, for repeatable reports
##   --all_unlocked=1  runs offer every card (default: only cards a new player has)
##   --weapon=handgun  equipped weapon id (see WeaponLibrary): its default deck
##                     and reward pool (general + its cards) are used
##   --only_weapons=1  just the weapon comparison (quick, for tuning weapons)
## Ammo: magazine and spare rounds carry over within a run; every non-boss room
## has an ammo box with WeaponLibrary.AMMO_ROOM_CHANCE, chests always give one.
## Not simulated: finding and swapping weapons in chests.
## What-if tuning, without editing the game (enemies only):
##   --dmg=0           added to every enemy's min and max damage
##   --hp_pct=100      enemy HP in percent
##   --boss_hp_mult=2.0 --hp_scale=0.1   boss HP multiplier, HP growth per room
##   --enrage=N        enemy damage growth per turn (default: MonsterBase.ENRAGE_PER_TURN)
##
## The battle rules mirror scripts/battle_manager.gd; keep them in sync when
## those change. Not simulated: spike traps and other exploration damage.

const RunScript := preload("res://autoloads/run_manager.gd")
const ENEMY_SCENES := {
	"zombie_easy_female": "res://resources/monsters/zombie_easy_female/zombie_easy_female.tscn",
	"vampire": "res://resources/monsters/vampire/vampire.tscn",
}
const HAND_SIZE := 3
const BASE_AP := 3
const EXPOSE_MULT := 1.5
const MAX_TURNS := 60 # Safety stop; counts as a loss.
## How much the AI values a round in the magazine, in damage: in normal fights
## of a run (saving ammo for the boss) and against the boss / in single tests.
const SAVE_ROUND_VALUE := 3.0
const BOSS_ROUND_VALUE := 1.5

var n := 2000
var sharpness := 0
var guard := 0
var ap := BASE_AP
var hp_bonus := 0
var dmg_bonus := 0
var all_unlocked := false
var enrage: int = MonsterBase.ENRAGE_PER_TURN
var hp_pct := 100
var boss_hp_mult: float = RunScript.BOSS_HP_MULTIPLIER
var hp_scale_per_room: float = RunScript.ENEMY_HP_SCALE_PER_ROOM
var enemy_base := {} ## key -> {name, hp, min, max}
## Equipped weapon: its default deck and card pool are used.
var weapon: WeaponData = WeaponLibrary.DEFAULT
var only_weapons := false

func _ready() -> void:
	_parse_args()
	_load_enemies()
	var player_hp: int = RunScript.PLAYER_STATS.max_health + hp_bonus
	print("\n=== Balance sim: %d battles per test, Iris %d HP, %d AP, sharpness +%d, guard +%d, %s ===" % [
		n, player_hp, ap, sharpness, guard, _weapon_name(weapon)])
	print("    enemies: dmg %+d, HP %d%%, +%d%% HP per room, boss HP x%.1f, enrage +%d/turn" % [
		dmg_bonus, hp_pct, roundi(hp_scale_per_room * 100), boss_hp_mult, enrage])

	if only_weapons:
		_report_weapons(player_hp)
		get_tree().quit()
		return
	_report_enemies(player_hp)
	_report_cards(player_hp)
	_report_runs(player_hp)
	_report_weapons(player_hp)
	get_tree().quit()

func _weapon_name(w: WeaponData) -> String:
	return w.weapon_name

## The equipped weapon's default starting deck (kit + default general cards).
func _starter() -> Array:
	return CardLibrary.default_deck(weapon)

## Cards rewards can offer with the equipped weapon (general + its pool):
## every one with --all_unlocked, else only those a new player has.
func _reward_pool() -> Array:
	var cards := CardLibrary.cards_for(weapon).filter(func(c): return c.offered)
	return cards if all_unlocked else cards.filter(func(c): return c.unlock_cost <= 0)

## A full magazine and the starting spare rounds, as a battle reads them.
func _fresh_ammo() -> Dictionary:
	return {"mag": weapon.magazine_size, "reserve": weapon.starting_reserve, "cap": weapon.magazine_size}

func _parse_args() -> void:
	var seed_value := 1
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		var v := int(parts[1])
		match parts[0]:
			"n": n = maxi(v, 10)
			"sharpness": sharpness = v
			"guard": guard = v
			"adrenaline": ap = BASE_AP + v
			"hp_bonus": hp_bonus = v
			"seed": seed_value = v
			"dmg": dmg_bonus = v
			"all_unlocked": all_unlocked = v != 0
			"only_weapons": only_weapons = v != 0
			"weapon":
				var w := WeaponLibrary.by_id(parts[1])
				if w:
					weapon = w
				else:
					push_error("Unknown weapon '%s'" % parts[1])
			"enrage": enrage = v
			"hp_pct": hp_pct = v
			"boss_hp_mult": boss_hp_mult = float(parts[1])
			"hp_scale": hp_scale_per_room = float(parts[1])
	seed(seed_value)

## Reads each enemy's stats from its scene (they're set in the scripts' _ready).
func _load_enemies() -> void:
	for key in ENEMY_SCENES:
		var e: Node = load(ENEMY_SCENES[key]).instantiate()
		add_child(e) # Runs _ready, which fills in the stats.
		enemy_base[key] = {"name": e.enemy_name, "hp": e.max_hp, "min": e.min_damage, "max": e.max_damage}
		e.free()

## Enemy as it appears in room `room_index` (same scaling as battle_manager).
func _enemy_for(key: String, room_index: int, boss := false) -> Dictionary:
	var b: Dictionary = enemy_base[key]
	var scale: float = (1.0 + hp_scale_per_room * room_index) * hp_pct / 100.0
	var bonus := dmg_bonus
	var name: String = b.name
	if boss:
		scale *= boss_hp_mult
		bonus += RunScript.BOSS_DAMAGE_BONUS
		name = RunScript.BOSS_NAME
	return {"name": name, "hp": roundi(b.hp * scale), "min": b.min + bonus, "max": b.max + bonus,
		"bleed": 0, "weaken": 0, "expose": 0, "intent": 0}

# ------------------------------------------------------------------ Battle

## Plays one battle. Returns {won, turns, hp_after}. `ammo` ({mag, reserve,
## cap}, see _fresh_ammo()) is updated with what's left, so a run carries it on.
func battle(deck_cards: Array, hp: int, max_hp: int, enemy: Dictionary, ammo := {}) -> Dictionary:
	if ammo.is_empty():
		ammo.merge(_fresh_ammo())
	var p := {"hp": hp, "max_hp": max_hp, "block": 0,
		"mag": ammo.mag, "reserve": ammo.reserve, "cap": ammo.cap,
		"round_value": ammo.get("round_value", 1.5)}
	var r := _battle(deck_cards, p, enemy)
	ammo.mag = p.mag
	ammo.reserve = p.reserve
	return r

func _battle(deck_cards: Array, p: Dictionary, enemy: Dictionary) -> Dictionary:
	var e := enemy.duplicate()
	var draw := deck_cards.duplicate()
	draw.shuffle()
	var discard := []
	var hand := []
	var turns := 0
	while turns < MAX_TURNS:
		turns += 1
		# Start of player turn.
		p.block = guard
		e.intent = randi_range(e.min, e.max) + enrage * (turns - 1)
		if p.cap > 0 and p.mag + p.reserve <= 0: # Gun dry: holster its cards.
			var keep := func(c): return not WeaponLibrary.is_gun_card(c)
			hand = hand.filter(keep)
			draw = draw.filter(keep)
			discard = discard.filter(keep)
		while hand.size() < HAND_SIZE:
			if draw.is_empty():
				if discard.is_empty():
					break
				draw = discard.duplicate()
				discard.clear()
				draw.shuffle()
			hand.append(draw.pop_front())

		var plan := _choose_play(hand, p, e)
		for c in plan:
			_play(c, p, e)
			if e.hp <= 0:
				break
		for c in plan:
			discard.append(c)
			hand.erase(c)
		if e.hp <= 0:
			return {"won": true, "turns": turns, "hp_after": p.hp}

		e.expose = maxi(e.expose - 1, 0)
		# Enemy turn: bleed, then attack.
		if e.bleed > 0:
			e.hp -= mini(e.bleed, e.hp)
			e.bleed -= 1
			if e.hp <= 0:
				return {"won": true, "turns": turns, "hp_after": p.hp}
		var dmg: int = maxi(e.intent - e.weaken, 0)
		e.weaken = 0
		var absorbed: int = mini(p.block, dmg)
		p.hp -= mini(dmg - absorbed, p.hp)
		if p.hp <= 0:
			return {"won": false, "turns": turns, "hp_after": 0}
	return {"won": false, "turns": turns, "hp_after": p.hp}

## Applies a card in CardData order; mutates p and e. Returns 1 if the card
## did nothing but cycle (gun clicked empty, or a reload with nothing to load),
## else 0. Ammo rules are WeaponLibrary's (p has the gun's mag/reserve/cap).
func _play(c: CardData, p: Dictionary, e: Dictionary) -> int:
	match WeaponLibrary.fire(c, p):
		WeaponLibrary.Shot.RELOADS:
			return 0 # Reloaded instead of firing (valued through the magazine).
		WeaponLibrary.Shot.CLICKS:
			return 1
	if c.damage > 0:
		for i in c.hits:
			var amount: int = c.damage + sharpness
			var dealt: int = int(amount * EXPOSE_MULT) if e.expose > 0 else amount
			dealt = mini(dealt, e.hp)
			e.hp -= dealt
			if c.lifesteal > 0:
				p.hp += mini(int(dealt * c.lifesteal / 100.0), p.max_hp - p.hp)
			if e.hp <= 0:
				return 0
	if c.block > 0:
		p.block += c.block
	if c.heal > 0:
		p.hp += mini(c.heal, p.max_hp - p.hp)
	if c.bleed > 0:
		e.bleed += c.bleed
	if c.weaken > 0:
		e.weaken += c.weaken
	if c.expose > 0:
		e.expose += c.expose
	if c.reload > 0 and WeaponLibrary.apply_reload(c, p) == 0:
		return 1
	return 0

## AI: tries every ordered subset of the hand that fits in AP (the player can
## see the enemy's intent) and keeps the one with the best score.
func _choose_play(hand: Array, p: Dictionary, e: Dictionary) -> Array:
	var best: Array = []
	var best_score := -INF
	for seq in _sequences(hand, ap):
		var score := _score(seq, p, e)
		if score > best_score:
			best_score = score
			best = seq
	return best

func _sequences(cards: Array, budget: int) -> Array:
	var out := [[]]
	for i in cards.size():
		var c: CardData = cards[i]
		if c.cost > budget:
			continue
		var rest := cards.duplicate()
		rest.remove_at(i)
		for tail in _sequences(rest, budget - c.cost):
			out.append([c] + tail)
	return out

## How good the position is after this play and the enemy's answer.
func _score(seq: Array, p: Dictionary, e: Dictionary) -> float:
	var p2 := p.duplicate()
	var e2 := e.duplicate()
	var fizzled := 0
	for c in seq:
		fizzled += _play(c, p2, e2)
		if e2.hp <= 0:
			return 10000.0 + p2.hp # Lethal now: best, keep the most HP.
	var dealt: float = e.hp - e2.hp
	e2.expose = maxi(e2.expose - 1, 0)
	var bleed_tick: int = mini(e2.bleed, e2.hp)
	if bleed_tick >= e2.hp:
		return 9000.0 + p2.hp # Bleed finishes it before it attacks.
	var dmg: int = maxi(e2.intent - e2.weaken, 0)
	var lost: int = mini(maxi(dmg - p2.block, 0), p2.hp)
	if lost >= p2.hp:
		return -10000.0 + dealt # Dies: worst.
	var future_bleed: float = (e2.bleed - 1) * e2.bleed / 2.0 # Stacks still to tick after this one.
	var healed: float = (p2.hp - p.hp)
	# Low HP makes HP matter more than damage.
	var hp_weight: float = 1.0 + 1.5 * (1.0 - float(p2.hp - lost) / p.max_hp)
	# Rounds in the magazine are worth a little (spending one must buy more
	# than `round_value` damage; a reload into an empty gun beats a weak hit),
	# and playing a dead card is a small plus: it cycles out of the hand.
	var ammo_value: float = p.round_value * (p2.mag - p.mag) + 0.5 * fizzled
	return dealt + bleed_tick + 0.6 * future_bleed + 3.0 * e2.expose \
		+ hp_weight * (healed - lost) + ammo_value - 0.01 * seq.size()

# ------------------------------------------------------------------ Reports

## `count` battles at full HP. `ammo` ({} = full magazine and starting spare
## rounds) is copied fresh for each.
func _many(deck_cards: Array, hp: int, enemy: Dictionary, count: int, ammo := {}) -> Dictionary:
	var wins := 0
	var turns := 0
	var lost := 0
	for i in count:
		var r := battle(deck_cards, hp, hp, enemy, ammo.duplicate())
		wins += int(r.won)
		turns += r.turns
		lost += hp - r.hp_after
	return {"win": 100.0 * wins / count, "turns": float(turns) / count, "lost": float(lost) / count}

func _report_enemies(hp: int) -> void:
	print("\n--- Starter deck + %s vs each enemy (full HP %d, full ammo) ---" % [_weapon_name(weapon), hp])
	print("%-24s %5s %7s %6s %8s %8s" % ["enemy (room)", "HP", "dmg", "win%", "turns", "HP lost"])
	var starter: Array = _starter()
	for room in [0, 3, 5]:
		for key in RunScript.ENCOUNTER_POOL:
			var e := _enemy_for(key, room)
			var r := _many(starter, hp, e, n)
			print("%-24s %5d %3d-%-3d %5.1f%% %8.2f %8.2f" % [
				"%s (room %d)" % [e.name, room + 1], e.hp, e.min, e.max, r.win, r.turns, r.lost])
	var boss := _enemy_for(RunScript.BOSS_ENEMY, RunScript.ROOMS_PER_RUN - 1, true)
	var rb := _many(starter, hp, boss, n)
	print("%-24s %5d %3d-%-3d %5.1f%% %8.2f %8.2f" % [
		boss.name + " (boss)", boss.hp, boss.min, boss.max, rb.win, rb.turns, rb.lost])

## Each pool card added once to the starter deck, against a mid-run Zombie and
## the boss. Lower turns / HP lost than the plain starter = stronger card.
func _report_cards(hp: int) -> void:
	var starter: Array = _starter()
	var mid := _enemy_for("zombie_easy_female", 3)
	var boss := _enemy_for(RunScript.BOSS_ENEMY, RunScript.ROOMS_PER_RUN - 1, true)
	var base_mid := _many(starter, hp, mid, n)
	var base_boss := _many(starter, hp, boss, n)
	print("\n--- Card strength: starter deck + 1 copy (vs %s room 4, and boss) ---" % mid.name)
	print("Baseline: mid %.2f turns / %.2f HP lost;  boss %.1f%% win / %.2f HP lost" % [
		base_mid.turns, base_mid.lost, base_boss.win, base_boss.lost])
	print("%-17s %4s %4s %10s %10s %10s %10s" % ["card", "cost", "", "d turns", "d HP lost", "boss win%", "boss lost"])
	var rows := []
	for c in CardLibrary.cards_for(weapon):
		var deck_cards: Array = starter + [c]
		var m := _many(deck_cards, hp, mid, n)
		var b := _many(deck_cards, hp, boss, n)
		rows.append({"c": c, "dt": m.turns - base_mid.turns, "dl": m.lost - base_mid.lost,
			"bw": b.win, "bl": b.lost})
	rows.sort_custom(func(a, b): return a.bw > b.bw or (a.bw == b.bw and a.bl < b.bl))
	for r in rows:
		var tag := "RARE" if r.c.is_rare() else ("lock" if r.c.unlock_cost > 0 else "")
		print("%-17s %4d %4s %+10.2f %+10.2f %9.1f%% %10.2f" % [r.c.card_name, r.c.cost, tag, r.dt, r.dl, r.bw, r.bl])

## Whole runs: path choices, rests, treasure, card rewards. HP carries over.
func _report_runs(hp: int) -> void:
	var count := maxi(n / 2, 10)
	print("\n--- Full runs with %s (%d each, %s) ---" % [weapon.weapon_name, count,
		"every card offered" if all_unlocked else "only cards unlocked from the start"])
	for policy in ["skip", "random", "greedy"]:
		var wins := 0
		var died_at := {}
		var deck_size := 0
		var hp_left := 0
		for i in count:
			var r := _run(hp, policy)
			if r.won:
				wins += 1
				deck_size += r.deck
				hp_left += r.hp
			else:
				died_at[r.room] = died_at.get(r.room, 0) + 1
		var deaths := PackedStringArray()
		for room in range(1, RunScript.ROOMS_PER_RUN + 1):
			if died_at.has(room):
				deaths.append("room %d: %.0f%%" % [room, 100.0 * died_at[room] / count])
		print("%-7s rewards: win %5.1f%%  (winners end with %.1f HP, deck %.1f)  deaths: %s" % [
			policy, 100.0 * wins / count, float(hp_left) / maxi(wins, 1),
			float(deck_size) / maxi(wins, 1), ", ".join(deaths)])
	print("  skip = never take a card, random = take a random offered card, greedy = take the")
	print("  offered card that does best vs the boss (fewest HP lost, deaths count as all HP),")
	print("  or skip if none beat the current starter deck.")

var _card_rank := {} ## card_name -> HP lost vs boss, lower is better (filled lazily for "greedy")

func _run(max_hp: int, policy: String) -> Dictionary:
	var deck_cards: Array = _starter()
	var hp := max_hp
	var ammo := _fresh_ammo()
	var room := {"type": RunScript.RoomType.FIGHT, "enemy": RunScript.ENCOUNTER_POOL.pick_random()}
	for index in RunScript.ROOMS_PER_RUN:
		if index > 0:
			room = _pick_path(_path_options(index), hp, max_hp)
		# Ammo box lying in the room (grabbed before the fight) or in the chest.
		if weapon and weapon.uses_ammo() and room.type != RunScript.RoomType.BOSS:
			if randf() < WeaponLibrary.AMMO_ROOM_CHANCE:
				ammo.reserve += weapon.ammo_per_pickup
			if room.type == RunScript.RoomType.TREASURE:
				ammo.reserve += weapon.ammo_per_pickup
		match room.type:
			RunScript.RoomType.FIGHT, RunScript.RoomType.BOSS:
				var boss: bool = room.type == RunScript.RoomType.BOSS
				# Like a careful player, save rounds for the boss: in normal
				# fights a shot must beat a melee hit by more before it's fired.
				ammo.round_value = BOSS_ROUND_VALUE if boss else SAVE_ROUND_VALUE
				var r := battle(deck_cards, hp, max_hp, _enemy_for(room.enemy, index, boss), ammo)
				if not r.won:
					return {"won": false, "room": index + 1}
				hp = r.hp_after
				if not boss:
					_reward(deck_cards, policy)
			RunScript.RoomType.TREASURE:
				_reward(deck_cards, policy)
			RunScript.RoomType.REST:
				hp = mini(hp + ceili(max_hp * RunScript.REST_HEAL_FRACTION), max_hp)
	return {"won": true, "room": RunScript.ROOMS_PER_RUN, "deck": deck_cards.size(), "hp": hp}

## Same rules as RunManager.get_next_room_choices() (index = room entered).
func _path_options(index: int) -> Array:
	if index >= RunScript.ROOMS_PER_RUN - 1:
		return [{"type": RunScript.RoomType.BOSS, "enemy": RunScript.BOSS_ENEMY}]
	if index == RunScript.ROOMS_PER_RUN - 2:
		return [{"type": RunScript.RoomType.REST}, {"type": RunScript.RoomType.TREASURE}]
	var out := []
	while out.size() < 2:
		var room := _random_room()
		if not out.any(func(c): return c.type == room.type and c.get("enemy") == room.get("enemy")):
			out.append(room)
	return out

func _random_room() -> Dictionary:
	var total := 0
	for w in RunScript.ROOM_WEIGHTS.values():
		total += w
	var roll := randi_range(1, total)
	for type in RunScript.ROOM_WEIGHTS:
		roll -= RunScript.ROOM_WEIGHTS[type]
		if roll <= 0:
			if type == RunScript.RoomType.FIGHT:
				return {"type": type, "enemy": RunScript.ENCOUNTER_POOL.pick_random()}
			return {"type": type}
	return {"type": RunScript.RoomType.REST}

## Rest when hurt, otherwise prefer treasure, then fights (for card rewards).
func _pick_path(options: Array, hp: int, max_hp: int) -> Dictionary:
	var order := [RunScript.RoomType.TREASURE, RunScript.RoomType.FIGHT, RunScript.RoomType.REST]
	if hp < max_hp * 0.6:
		order = [RunScript.RoomType.REST, RunScript.RoomType.TREASURE, RunScript.RoomType.FIGHT]
	for type in order:
		for o in options:
			if o.type == type:
				return o
	return options[0]

func _reward(deck_cards: Array, policy: String) -> void:
	if policy == "skip":
		return
	var pool := _reward_pool()
	var offer := CardLibrary.roll_offer(pool, RunScript.REWARD_CHOICES)
	if policy == "random":
		deck_cards.append(offer.pick_random())
		return
	if _card_rank.is_empty():
		_rank_cards()
	var best: CardData = null
	for c in offer:
		if _card_rank[c.card_name] < _card_rank["(none)"] and (best == null or _card_rank[c.card_name] < _card_rank[best.card_name]):
			best = c
	if best:
		deck_cards.append(best)

func _rank_cards() -> void:
	var hp: int = RunScript.PLAYER_STATS.max_health + hp_bonus
	var boss := _enemy_for(RunScript.BOSS_ENEMY, RunScript.ROOMS_PER_RUN - 1, true)
	var count := maxi(n / 4, 50)
	var starter := _starter()
	# Judge cards in a mid-run boss fight: a loaded gun and half the starting
	# spare rounds, so ammo-hungry cards aren't overrated.
	var late := {"mag": weapon.magazine_size, "reserve": weapon.starting_reserve / 2, "cap": weapon.magazine_size}
	_card_rank["(none)"] = _many(starter, hp, boss, count, late).lost
	for c in CardLibrary.cards_for(weapon):
		_card_rank[c.card_name] = _many(starter + [c], hp, boss, count, late).lost

## Full runs with each weapon, to compare them. Uses the run settings above;
## resets the greedy card ranking per weapon.
func _report_weapons(hp: int) -> void:
	var count := maxi(n / 2, 10)
	var keep := weapon
	print("\n--- Weapons: full runs, each with its default deck and card pool (%d each) ---" % count)
	print("%-12s %10s %10s %10s" % ["weapon", "skip", "random", "greedy"])
	var options: Array = WeaponLibrary.ALL.duplicate()
	for w in options:
		weapon = w
		_card_rank.clear()
		var cols := PackedStringArray()
		for policy in ["skip", "random", "greedy"]:
			var wins := 0
			for i in count:
				wins += int(_run(hp, policy).won)
			cols.append("%9.1f%%" % (100.0 * wins / count))
		print("%-12s %s" % [_weapon_name(w), " ".join(cols)])
	weapon = keep
	_card_rank.clear()
