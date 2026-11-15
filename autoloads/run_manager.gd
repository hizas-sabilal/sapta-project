extends Node
## Holds everything that persists across rooms within a single run.
## A new run starts when the player presses Start; dying or beating the boss ends it.

const PLAYER_STATS: PlayerStats = preload("res://resources/characters/iris/iris_stats.tres")

const STARTING_DECK: Array[CardData] = [
	preload("res://resources/cardsdata/bandage.tres"),
	preload("res://resources/cardsdata/block.tres"),
	preload("res://resources/cardsdata/slash.tres"),
	preload("res://resources/cardsdata/stab.tres"),
	preload("res://resources/cardsdata/double_stab.tres"),
]

## Cards that can be offered as battle / treasure rewards (every card in the game).
const CARD_POOL: Array[CardData] = [
	preload("res://resources/cardsdata/slash.tres"),
	preload("res://resources/cardsdata/stab.tres"),
	preload("res://resources/cardsdata/double_stab.tres"),
	preload("res://resources/cardsdata/heavy_strike.tres"),
	preload("res://resources/cardsdata/flurry.tres"),
	preload("res://resources/cardsdata/serrated_edge.tres"),
	preload("res://resources/cardsdata/block.tres"),
	preload("res://resources/cardsdata/shield_bash.tres"),
	preload("res://resources/cardsdata/iron_wall.tres"),
	preload("res://resources/cardsdata/parry.tres"),
	preload("res://resources/cardsdata/bandage.tres"),
	preload("res://resources/cardsdata/second_wind.tres"),
	preload("res://resources/cardsdata/blood_drain.tres"),
	preload("res://resources/cardsdata/hemorrhage.tres"),
	preload("res://resources/cardsdata/intimidate.tres"),
	preload("res://resources/cardsdata/expose.tres"),
]

const REWARD_CHOICES := 3

# ---------------------------------------------------------------- Room map

enum RoomType { FIGHT, TREASURE, REST, BOSS }

const ROOM_INFO := {
	RoomType.FIGHT: {"name": "Fight", "desc": "Battle a monster.\nWin to earn a card."},
	RoomType.TREASURE: {"name": "Treasure", "desc": "Open a chest and\npick a card."},
	RoomType.REST: {"name": "Campfire", "desc": "Rest to recover\n30% of your max HP."},
	RoomType.BOSS: {"name": "Boss", "desc": "The Vampire Lord awaits."},
}

## Total rooms in a run, including the first fight and the final boss.
const ROOMS_PER_RUN := 7
## Weights for the random rooms in the middle of the run.
const ROOM_WEIGHTS := {RoomType.FIGHT: 4, RoomType.TREASURE: 1, RoomType.REST: 1}
## Keys of Constants.ENEMIES that normal fights draw from.
const ENCOUNTER_POOL: Array[String] = ["zombie_easy_female", "vampire"]

const REST_HEAL_FRACTION := 0.3
## Normal enemies get +10% HP per room into the run.
const ENEMY_HP_SCALE_PER_ROOM := 0.1

const BOSS_ENEMY := "vampire"
const BOSS_NAME := "Vampire Lord"
const BOSS_HP_MULTIPLIER := 2.0
const BOSS_DAMAGE_BONUS := 1

# ---------------------------------------------------------------- Run state

var max_hp: int
var hp: int
var deck: Array[CardData] = []
var battles_won := 0

## Seed for this run's room layouts: each run is different, but a given run
## always generates the same rooms (print it to reproduce a layout).
var run_seed := 0

## 0-based index of the room the player is in.
var room_index := 0
## {"type": RoomType, "enemy": String (fights/boss only)}
var current_room: Dictionary = {}

func start_new_run() -> void:
	max_hp = PLAYER_STATS.max_health
	hp = max_hp
	deck = STARTING_DECK.duplicate()
	battles_won = 0
	room_index = 0
	run_seed = randi()
	current_room = _make_room(RoomType.FIGHT) # Always open with a fight.
	print("New run started: seed ", run_seed, ", HP ", hp, "/", max_hp, ", deck of ", deck.size())

func room_seed() -> int:
	return hash([run_seed, room_index])

func add_card(card: CardData) -> void:
	deck.append(card)
	print("Added ", card.card_name, " to deck (", deck.size(), " cards)")

## Distinct random cards from the pool.
func get_reward_choices() -> Array[CardData]:
	var pool := CARD_POOL.duplicate()
	pool.shuffle()
	return pool.slice(0, REWARD_CHOICES)

func is_boss_room() -> bool:
	return current_room.get("type") == RoomType.BOSS

## Options offered at the exit of the current room.
func get_next_room_choices() -> Array[Dictionary]:
	var next := room_index + 1
	if next >= ROOMS_PER_RUN - 1:
		return [_make_room(RoomType.BOSS)]
	if next == ROOMS_PER_RUN - 2:
		# A breather right before the boss.
		return [_make_room(RoomType.REST), _make_room(RoomType.TREASURE)]

	var choices: Array[Dictionary] = []
	while choices.size() < 2:
		var room := _make_room(_weighted_room_type())
		if not choices.any(func(c): return _same_room(c, room)):
			choices.append(room)
	return choices

func advance_to(room: Dictionary) -> void:
	room_index += 1
	current_room = room
	print("Entering room ", room_index + 1, "/", ROOMS_PER_RUN, ": ", describe_room(room))

## Heals a fraction of max HP; returns the amount actually healed.
func rest() -> int:
	var before := hp
	hp = min(hp + ceili(max_hp * REST_HEAL_FRACTION), max_hp)
	return hp - before

## How hard the current room's layout is: 0 in the first room, 1 in the last
## room before the boss. Drives room size, features, spikes and monster count.
func difficulty() -> float:
	return clampf(room_index / float(ROOMS_PER_RUN - 2), 0.0, 1.0)

func enemy_hp_scale() -> float:
	return 1.0 + ENEMY_HP_SCALE_PER_ROOM * room_index

func describe_room(room: Dictionary) -> String:
	var info: Dictionary = ROOM_INFO[room.type]
	if room.type == RoomType.FIGHT:
		return "%s: %s" % [info.name, Constants.ENEMY_NAMES.get(room.enemy, room.enemy)]
	return info.name

func _make_room(type: RoomType) -> Dictionary:
	var room := {"type": type}
	if type == RoomType.FIGHT:
		room.enemy = ENCOUNTER_POOL.pick_random()
	elif type == RoomType.BOSS:
		room.enemy = BOSS_ENEMY
	return room

func _weighted_room_type() -> RoomType:
	var total := 0
	for w in ROOM_WEIGHTS.values():
		total += w
	var roll := randi_range(1, total)
	for type in ROOM_WEIGHTS:
		roll -= ROOM_WEIGHTS[type]
		if roll <= 0:
			return type
	return RoomType.FIGHT

func _same_room(a: Dictionary, b: Dictionary) -> bool:
	return a.type == b.type and a.get("enemy", "") == b.get("enemy", "")
