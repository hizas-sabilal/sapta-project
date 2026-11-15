extends Resource
class_name CardData
## One card's numbers. Every non-zero effect is applied when the card is played,
## in this order: damage (x hits, with lifesteal), block, heal, bleed, weaken, expose.
## The card's rules text is generated from these values (see rules_text()), so the
## text on the card always matches what it does. `description` is optional flavor.

enum Type { ATTACK, DEFENSE, HEAL, DEBUFF }
## Rare cards are offered less often and only 1 copy fits in the starting deck.
enum Rarity { COMMON, RARE }

@export var card_name: String
@export var type: Type = Type.ATTACK
@export var cost: int = 1
@export var rarity: Rarity = Rarity.COMMON
## Coins to unlock it in the main menu's Deck screen. 0 = unlocked from the
## start. Locked cards can also be found in runs (see CardLibrary).
@export var unlock_cost: int = 0

@export_group("Effects")
## Damage per hit.
@export var damage: int
## How many times the damage is dealt.
@export_range(1, 10) var hits: int = 1
## Heal this % of the damage actually dealt.
@export_range(0, 100) var lifesteal: int
@export var block: int
@export var heal: int
## Enemy loses this much HP at the start of each of its turns; drops by 1 each time.
@export var bleed: int
## Enemy's next attack deals this much less damage.
@export var weaken: int
## For this many of your turns (counting the current one) the enemy takes 50% more
## damage. Only hits after this card in the same turn benefit, so play it first.
@export var expose: int

@export_multiline var description: String

const TYPE_NAMES := {Type.ATTACK: "Attack", Type.DEFENSE: "Defense", Type.HEAL: "Heal", Type.DEBUFF: "Debuff"}

func type_name() -> String:
	return TYPE_NAMES[type]

func is_rare() -> bool:
	return rarity == Rarity.RARE

## Stable id for saving: the resource's file name ("slash" for slash.tres).
func id() -> String:
	return resource_path.get_file().get_basename()

## Plain-language rules text built from the effect values.
func rules_text() -> String:
	var lines: PackedStringArray = []
	if damage > 0:
		if hits > 1:
			lines.append("Deal %d damage %d times." % [damage, hits])
		else:
			lines.append("Deal %d damage." % damage)
		if lifesteal >= 100:
			lines.append("Heal the damage dealt.")
		elif lifesteal > 0:
			lines.append("Heal %d%% of damage dealt." % lifesteal)
	if block > 0:
		lines.append("Gain %d Block." % block)
	if heal > 0:
		lines.append("Heal %d HP." % heal)
	if bleed > 0:
		lines.append("Apply %d Bleed." % bleed)
	if weaken > 0:
		lines.append("Enemy's next attack -%d." % weaken)
	if expose > 0:
		lines.append("Enemy takes +50%% damage for %d turn%s." % [expose, "" if expose == 1 else "s"])
	return "\n".join(lines)
