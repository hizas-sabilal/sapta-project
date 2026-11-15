extends Node
## Progress that survives between runs: coins and the skill tree.
## Coins are kept even when a run ends in death; spend them in the main
## menu's Skills screen. Saved to user://meta_progress.cfg after every change.

signal coins_changed(coins: int)
signal skills_changed

const SAVE_PATH := "user://meta_progress.cfg"

## Coins for clearing a room (reaching its exit, or beating the boss).
const ROOM_CLEAR_COINS := 5
## Chance that a room has coins lying around, before the Treasure Sense skill.
const COIN_ROOM_CHANCE := 0.25

## The skill tree. Each skill needs its parent (`requires`) at level 1+.
## cost of the next level = cost + cost_step * current level.
## `per_level` is the bonus each level gives (see the getters below).
const SKILLS := [
	{"id": "will", "name": "Will to Live", "branch": "root", "requires": "",
		"max": 1, "cost": 10, "cost_step": 0, "per_level": 3,
		"desc": "+%d Max HP. Unlocks the three branches."},

	{"id": "toughness", "name": "Toughness", "branch": "Body", "requires": "will",
		"max": 5, "cost": 15, "cost_step": 10, "per_level": 2,
		"desc": "+%d Max HP per level."},
	{"id": "thick_soles", "name": "Thick Soles", "branch": "Body", "requires": "toughness",
		"max": 2, "cost": 25, "cost_step": 20, "per_level": 1,
		"desc": "Spikes deal %d less damage per level (min 1)."},
	{"id": "camper", "name": "Camper", "branch": "Body", "requires": "thick_soles",
		"max": 3, "cost": 30, "cost_step": 15, "per_level": 10,
		"desc": "Campfires heal +%d%% of Max HP per level."},

	{"id": "sharpness", "name": "Sharpness", "branch": "Combat", "requires": "will",
		"max": 3, "cost": 20, "cost_step": 15, "per_level": 1,
		"desc": "Attack cards deal +%d damage per hit per level."},
	{"id": "guard", "name": "Guard", "branch": "Combat", "requires": "sharpness",
		"max": 3, "cost": 25, "cost_step": 15, "per_level": 1,
		"desc": "Start every turn with +%d Block per level."},
	{"id": "adrenaline", "name": "Adrenaline", "branch": "Combat", "requires": "guard",
		"max": 1, "cost": 120, "cost_step": 0, "per_level": 1,
		"desc": "+%d AP every turn."},

	{"id": "greed", "name": "Greed", "branch": "Fortune", "requires": "will",
		"max": 3, "cost": 15, "cost_step": 10, "per_level": 2,
		"desc": "+%d coins per room cleared per level."},
	{"id": "treasure_sense", "name": "Treasure Sense", "branch": "Fortune", "requires": "greed",
		"max": 3, "cost": 20, "cost_step": 15, "per_level": 10,
		"desc": "+%d%% chance per level that a room has coins."},
	{"id": "keen_eye", "name": "Keen Eye", "branch": "Fortune", "requires": "treasure_sense",
		"max": 1, "cost": 80, "cost_step": 0, "per_level": 1,
		"desc": "Card rewards offer +%d extra choice."},
]

var coins := 0
var _levels := {} ## skill id -> level

func _ready() -> void:
	_load()

# ---------------------------------------------------------------- Coins

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	_save()
	coins_changed.emit(coins)

## Coins for clearing a room, including the Greed bonus.
func room_clear_reward() -> int:
	return ROOM_CLEAR_COINS + bonus("greed")

func coin_room_chance() -> float:
	return clampf(COIN_ROOM_CHANCE + bonus("treasure_sense") / 100.0, 0.0, 1.0)

# ---------------------------------------------------------------- Skills

func skill(id: String) -> Dictionary:
	for s in SKILLS:
		if s.id == id:
			return s
	return {}

func level(id: String) -> int:
	return _levels.get(id, 0)

## Total bonus a skill gives right now (level * per_level).
func bonus(id: String) -> int:
	return level(id) * int(skill(id).get("per_level", 0))

func is_maxed(id: String) -> bool:
	return level(id) >= skill(id).max

func is_unlocked(id: String) -> bool:
	var parent: String = skill(id).requires
	return parent == "" or level(parent) >= 1

## Price of the next level (0 if maxed).
func next_cost(id: String) -> int:
	if is_maxed(id):
		return 0
	var s := skill(id)
	return s.cost + s.cost_step * level(id)

func can_buy(id: String) -> bool:
	return is_unlocked(id) and not is_maxed(id) and coins >= next_cost(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= next_cost(id)
	_levels[id] = level(id) + 1
	_save()
	coins_changed.emit(coins)
	skills_changed.emit()
	return true

## Coins spent on all skills so far.
func total_spent() -> int:
	var total := 0
	for s in SKILLS:
		for l in level(s.id):
			total += s.cost + s.cost_step * l
	return total

## Resets every skill and gives back all coins spent on them.
func refund_all() -> int:
	var refunded := total_spent()
	coins += refunded
	_levels.clear()
	_save()
	coins_changed.emit(coins)
	skills_changed.emit()
	return refunded

## Skill description with its per-level value filled in.
func describe(id: String) -> String:
	var s := skill(id)
	return s.desc % s.per_level

# ---------------------------------------------------------------- Save

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "coins", coins)
	config.set_value("meta", "skills", _levels)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save progress: %s" % error_string(err))

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	coins = int(config.get_value("meta", "coins", 0))
	var saved = config.get_value("meta", "skills", {})
	if saved is Dictionary:
		for id in saved:
			if not skill(id).is_empty(): # Skip skills that no longer exist.
				_levels[id] = clampi(int(saved[id]), 0, skill(id).max)
