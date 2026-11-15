class_name CardLibrary
## Every card in the game, plus the rules shared by runs, the Deck menu and
## the balance sim: weighted reward offers and starting-deck limits.
## Which cards are unlocked lives in Progress (it's saved between runs).

## Every card. A new card only needs adding here (and its .tres).
const ALL: Array[CardData] = [
	# Unlocked from the start.
	preload("res://resources/cardsdata/slash.tres"),
	preload("res://resources/cardsdata/stab.tres"),
	preload("res://resources/cardsdata/double_stab.tres"),
	preload("res://resources/cardsdata/heavy_strike.tres"),
	preload("res://resources/cardsdata/flurry.tres"),
	preload("res://resources/cardsdata/serrated_edge.tres"),
	preload("res://resources/cardsdata/block.tres"),
	preload("res://resources/cardsdata/shield_bash.tres"),
	preload("res://resources/cardsdata/parry.tres"),
	preload("res://resources/cardsdata/bandage.tres"),
	preload("res://resources/cardsdata/intimidate.tres"),
	# Locked commons (unlock_cost > 0).
	preload("res://resources/cardsdata/iron_wall.tres"),
	preload("res://resources/cardsdata/second_wind.tres"),
	preload("res://resources/cardsdata/blood_drain.tres"),
	preload("res://resources/cardsdata/hemorrhage.tres"),
	preload("res://resources/cardsdata/expose.tres"),
	preload("res://resources/cardsdata/crippling_cut.tres"),
	# Locked rares.
	preload("res://resources/cardsdata/execution.tres"),
	preload("res://resources/cardsdata/bulwark_slam.tres"),
	preload("res://resources/cardsdata/thousand_cuts.tres"),
	preload("res://resources/cardsdata/vampire_kiss.tres"),
]

## The starting deck before the player builds their own.
const DEFAULT_DECK: Array[CardData] = [
	preload("res://resources/cardsdata/bandage.tres"),
	preload("res://resources/cardsdata/block.tres"),
	preload("res://resources/cardsdata/slash.tres"),
	preload("res://resources/cardsdata/stab.tres"),
	preload("res://resources/cardsdata/double_stab.tres"),
]

## Reward offers: a rare is this many times less likely than a common.
const COMMON_WEIGHT := 4
const RARE_WEIGHT := 1
## Chance that a reward offer swaps one card for a locked one ("NEW!").
## Picking it unlocks it for good.
const BATTLE_DISCOVERY_CHANCE := 0.2
const TREASURE_DISCOVERY_CHANCE := 1.0

## Starting deck limits.
const DECK_SIZE := 5
const MAX_COPIES := 2
const MAX_RARE_COPIES := 1

static func by_id(id: String) -> CardData:
	for card in ALL:
		if card.id() == id:
			return card
	return null

## `count` distinct cards from `pool`, rares less likely. With chance
## `discovery_chance` one of them is a random card from `locked` instead.
static func roll_offer(pool: Array, count: int, locked: Array = [], discovery_chance := 0.0) -> Array[CardData]:
	var offer: Array[CardData] = []
	var left := pool.duplicate()
	while offer.size() < count and not left.is_empty():
		var pick: CardData = _weighted_pick(left)
		offer.append(pick)
		left.erase(pick)
	if not locked.is_empty() and randf() < discovery_chance:
		var found: CardData = locked.pick_random()
		if offer.size() < count:
			offer.append(found)
		else:
			offer[randi() % offer.size()] = found
	return offer

static func _weighted_pick(cards: Array) -> CardData:
	var total := 0
	for c in cards:
		total += weight(c)
	var roll := randi_range(1, total)
	for c in cards:
		roll -= weight(c)
		if roll <= 0:
			return c
	return cards.back()

static func weight(card: CardData) -> int:
	return RARE_WEIGHT if card.is_rare() else COMMON_WEIGHT

static func max_copies(card: CardData) -> int:
	return MAX_RARE_COPIES if card.is_rare() else MAX_COPIES

static func count_in(deck: Array, card: CardData) -> int:
	return deck.count(card)

## Why `card` can't be added to `deck` right now, or "" if it can.
static func add_problem(deck: Array, card: CardData) -> String:
	if deck.size() >= DECK_SIZE:
		return "The deck is full (%d cards). Remove one first." % DECK_SIZE
	if count_in(deck, card) >= max_copies(card):
		if card.is_rare():
			return "Only %d copy of a rare card is allowed." % MAX_RARE_COPIES
		return "At most %d copies of a card." % MAX_COPIES
	return ""

## Why `deck` can't start a run, or "" if it's fine.
static func deck_problem(deck: Array) -> String:
	if deck.size() != DECK_SIZE:
		return "The starting deck needs exactly %d cards (has %d)." % [DECK_SIZE, deck.size()]
	for card in deck:
		if count_in(deck, card) > max_copies(card):
			return "Too many copies of %s." % card.card_name
	if not deck.any(func(c): return c.damage > 0 or c.bleed > 0):
		return "The deck needs at least one card that deals damage."
	return ""
