class_name WeaponLibrary
## Every weapon in the game, plus the ammo rules shared by battles, the run and
## the balance sim. Which weapons are unlocked lives in Progress (saved).

## Every weapon. A new weapon only needs adding here (and its .tres + cards in
## its pool).
const ALL: Array[WeaponData] = [
	preload("res://resources/weapons/knife/knife.tres"),
	preload("res://resources/weapons/handgun/handgun.tres"),
	preload("res://resources/weapons/lead_pipe/lead_pipe.tres"),
	preload("res://resources/weapons/shotgun/shotgun.tres"),
]

## Equipped when the player hasn't picked one (unlocked from the start).
const DEFAULT: WeaponData = preload("res://resources/weapons/handgun/handgun.tres")

## Chance a fight / treasure / rest room has an ammo box (only with a gun).
const AMMO_ROOM_CHANCE := 0.4
## Chance an opened chest also holds a weapon other than the equipped one.
## Taking a locked one unlocks it for good.
const WEAPON_FIND_CHANCE := 0.35

## Cards that need rounds to do anything: they fire or reload. When the gun is
## completely dry (no rounds in the magazine or reserve) these are holstered:
## taken out of the battle's draw, so the deck falls back on its melee cards.
static func is_gun_card(card: CardData) -> bool:
	return card.ammo > 0 or card.reload > 0

static func by_id(id: String) -> WeaponData:
	for weapon in ALL:
		if weapon.id() == id:
			return weapon
	return null

## What a card does with the gun when played (see fire()).
enum Shot {
	FIRES, ## Enough rounds (or the card needs none): it plays normally.
	RELOADS, ## Too few rounds: it reloads from the reserve instead, nothing else.
	CLICKS, ## Too few rounds and no spares: nothing happens.
}

## Ammo rules for playing one card, shared by battles, the hand preview and
## the balance sim. `gun` is {mag, reserve, cap} and is updated. Step 2 is
## apply_reload().
## Step 1, before the card's effects: fire its rounds. If the magazine is too
## low, the card instead reloads (fills the magazine from the reserve) and has
## no other effect, or clicks when there are no spare rounds either.
static func fire(card: CardData, gun: Dictionary) -> Shot:
	if gun.mag >= card.ammo:
		gun.mag -= card.ammo
		return Shot.FIRES
	return Shot.RELOADS if load_rounds(gun, gun.cap) > 0 else Shot.CLICKS

## Step 2, after the card's other effects: its own `reload`. Returns the rounds loaded.
## (Not called `reload`: that's a built-in method of every script.)
static func apply_reload(card: CardData, gun: Dictionary) -> int:
	return load_rounds(gun, card.reload) if card.reload > 0 else 0

## Moves up to `amount` rounds from the reserve into the magazine.
static func load_rounds(gun: Dictionary, amount: int) -> int:
	var loaded := mini(amount, mini(gun.reserve, gun.cap - gun.mag))
	gun.mag += loaded
	gun.reserve -= loaded
	return loaded

## Plays `cards` in order against `gun` ({mag, reserve, cap}, not changed),
## the way a battle resolves them. Returns {gun: the state afterwards,
## shots: Array of Shot, one per card}.
static func resolve_ammo(cards: Array, gun: Dictionary) -> Dictionary:
	var state := gun.duplicate()
	var shots: Array = []
	for card: CardData in cards:
		var shot := fire(card, state)
		shots.append(shot)
		if shot == Shot.FIRES:
			apply_reload(card, state)
	return {"gun": state, "shots": shots}
