class_name CardLibrary
## Every card in the game, plus the rules shared by runs, the Deck menu and
## the balance sim: weighted reward offers and starting-deck limits.
## Which cards are unlocked lives in Progress (it's saved between runs).
##
## A card is either general (below: usable with any weapon) or belongs to one
## weapon's pool (WeaponData.pool). A deck holds general cards plus cards of
## its weapon only; see cards_for().

## General cards. A new general card only needs adding here (and its .tres);
## a new weapon card goes in its weapon's pool. Card file names must be unique
## across the game (they're the saved ids).
const GENERAL: Array[CardData] = [
	# Unlocked from the start.
	preload("res://resources/cardsdata/block.tres"),
	preload("res://resources/cardsdata/parry.tres"),
	preload("res://resources/cardsdata/bandage.tres"),
	preload("res://resources/cardsdata/intimidate.tres"),
	preload("res://resources/cardsdata/shield_bash.tres"),
	# Locked commons (unlock_cost > 0).
	preload("res://resources/cardsdata/iron_wall.tres"),
	preload("res://resources/cardsdata/second_wind.tres"),
	preload("res://resources/cardsdata/expose.tres"),
	# Locked rares.
	preload("res://resources/cardsdata/bulwark_slam.tres"),
]

## The general half of every weapon's default starting deck (the other half
## is the weapon's kit; see WeaponData.default_deck()).
const DEFAULT_GENERAL: Array[CardData] = [
	preload("res://resources/cardsdata/block.tres"),
	preload("res://resources/cardsdata/bandage.tres"),
]

static var _all: Array[CardData] = []

## Every card in the game: general cards, then each weapon's pool.
static func all() -> Array[CardData]:
	if _all.is_empty():
		_all = GENERAL.duplicate()
		for weapon in WeaponLibrary.ALL:
			_all.append_array(weapon.pool)
	return _all

## The cards a deck with `weapon` can hold: general cards, then its pool.
static func cards_for(weapon: WeaponData) -> Array[CardData]:
	var cards := GENERAL.duplicate()
	cards.append_array(weapon.pool)
	return cards

## `weapon`'s starting deck until the player builds their own: its kit plus
## the default general cards.
static func default_deck(weapon: WeaponData) -> Array[CardData]:
	var deck := weapon.kit.duplicate()
	deck.append_array(DEFAULT_GENERAL)
	return deck

## The weapon a card belongs to, or null for general cards.
static func weapon_of(card: CardData) -> WeaponData:
	for weapon in WeaponLibrary.ALL:
		if weapon.owns(card):
			return weapon
	return null

## Reward offers: a rare is this many times less likely than a common.
const COMMON_WEIGHT := 4
const RARE_WEIGHT := 1
## Chance that a reward offer swaps one card for a locked one ("NEW!").
## Picking it unlocks it for good.
const BATTLE_DISCOVERY_CHANCE := 0.2
const TREASURE_DISCOVERY_CHANCE := 1.0

## Starting deck limits.
const DECK_SIZE := 6
const MAX_COPIES := 2
const MAX_RARE_COPIES := 1

static func by_id(id: String) -> CardData:
	for card in all():
		if card.id() == id:
			return card
	return null

## `count` distinct cards from `pool`, rares less likely. With chance
## `discovery_chance` one of them is a random card from `locked` instead.
## Cards with `offered` off are left out.
static func roll_offer(pool: Array, count: int, locked: Array = [], discovery_chance := 0.0) -> Array[CardData]:
	var offer: Array[CardData] = []
	var left := pool.filter(func(c): return c.offered)
	locked = locked.filter(func(c): return c.offered)
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

## Why `deck` can't start a run with `weapon`, or "" if it's fine.
static func deck_problem(deck: Array, weapon: WeaponData) -> String:
	if deck.size() != DECK_SIZE:
		return "The starting deck needs exactly %d cards (has %d)." % [DECK_SIZE, deck.size()]
	for card in deck:
		if count_in(deck, card) > max_copies(card):
			return "Too many copies of %s." % card.card_name
		var owner := weapon_of(card)
		if owner != null and owner != weapon:
			return "%s is a %s card." % [card.card_name, owner.weapon_name]
	if not deck.any(func(c): return c.damage > 0 or c.bleed > 0):
		return "The deck needs at least one card that deals damage."
	if weapon.uses_ammo() and not deck.any(func(c): return c.reload > 0):
		return "A gun deck needs at least one card that reloads."
	return ""
