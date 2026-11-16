extends Resource
class_name WeaponData
## A weapon Iris can equip (one at a time). Every card in the game is either a
## general card (CardLibrary.GENERAL: dodging, bandages, shoving...) or belongs
## to one weapon's `pool`. A deck only ever holds general cards and cards of
## the equipped weapon: card rewards offer those, each weapon has its own
## starting deck, and swapping weapons mid-run drops the old weapon's cards
## for the new weapon's `kit`.
##
## Guns have a magazine: cards with `ammo` fire rounds from it, cards with
## `reload` refill it from the reserve. The magazine and the reserve both carry
## over between fights for the whole run; ammo boxes in rooms top the reserve up.
## Melee weapons (magazine_size 0) never need ammo.

@export var weapon_name: String
@export_multiline var description: String
## Every card of this weapon: offered as rewards while it's equipped, and
## usable in its starting deck once unlocked. Each card belongs to one weapon.
@export var pool: Array[CardData] = []
## Cards it comes with when found mid-run, and the weapon half of its default
## starting deck (see CardLibrary.default_deck()). Must be cards from `pool`
## that are unlocked from the start.
## (This script must not use CardLibrary/WeaponLibrary: they preload weapons,
## which would make a load cycle.)
@export var kit: Array[CardData] = []

@export_group("Ammo")
## Rounds the magazine holds. 0 = melee weapon, no ammo at all.
@export var magazine_size: int
## Spare rounds a run starts with (the magazine also starts full). A weapon
## found mid-run comes with the same.
@export var starting_reserve: int
## Rounds in one ammo box.
@export var ammo_per_pickup: int

@export_group("Unlock")
## Coins to unlock it in the main menu's Equipment screen. 0 = unlocked from
## the start. Locked weapons can also be found in chests.
@export var unlock_cost: int

## Stable id for saving: the resource's file name ("handgun" for handgun.tres).
func id() -> String:
	return resource_path.get_file().get_basename()

func uses_ammo() -> bool:
	return magazine_size > 0

## True if `card` is one of this weapon's cards (false for general cards).
func owns(card: CardData) -> bool:
	return pool.has(card)

## One line of stats for menus.
func stats_text() -> String:
	if not uses_ammo():
		return "Melee: never runs out of ammo."
	return "Magazine %d   -   Starts with %d spare rounds   -   Ammo box: +%d" % [
		magazine_size, starting_reserve, ammo_per_pickup]

## "Shot x2, Double Shot, Reload"
static func names_text(cards: Array) -> String:
	var counts := {}
	for card in cards:
		counts[card] = counts.get(card, 0) + 1
	var names: PackedStringArray = []
	for card in counts:
		names.append(card.card_name + (" x%d" % counts[card] if counts[card] > 1 else ""))
	return ", ".join(names)
