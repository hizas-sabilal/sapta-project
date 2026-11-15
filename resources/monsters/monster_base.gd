extends Node2D
class_name MonsterBase

@onready var anim = $AnimatedSprite2D
@export var enemy_name : String
@export var max_hp : int
@export var current_hp : int
@export var min_damage : int
@export var max_damage : int
@export var intent_pool : Array[int]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_hp = max_hp
	anim.flip_h = true
	anim.play(Constants.ANIM_IDLE);
	print("Enemy ", enemy_name , " instantiated!")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Status effects from cards (see CardData for what each does).
var bleed := 0
var weaken := 0
var expose := 0
## Damage rolled for the enemy's next attack, shown to the player as its intent.
var intent_damage := 0

const EXPOSE_MULTIPLIER := 1.5

func take_damage(amount: int):
	current_hp = max(current_hp - amount, 0)
	print(enemy_name, " HP : ", current_hp)

## A hit from a card: boosted while exposed. Returns the damage actually dealt.
func take_hit(amount: int) -> int:
	var dealt := int(amount * EXPOSE_MULTIPLIER) if expose > 0 else amount
	dealt = mini(dealt, current_hp) # Lifesteal can't heal off overkill.
	take_damage(dealt)
	return dealt

## Start of the enemy's turn: bleed deals its stacks as damage, then fades by 1.
func tick_bleed() -> int:
	if bleed <= 0:
		return 0
	var dealt := mini(bleed, current_hp)
	take_damage(dealt)
	bleed -= 1
	return dealt

## End of the player's turn: exposed lasts a set number of player turns.
func tick_expose() -> void:
	expose = maxi(expose - 1, 0)

func roll_intent() -> void:
	intent_damage = randi_range(min_damage, max_damage)

## What the next attack will deal after weaken.
func planned_damage() -> int:
	return maxi(intent_damage - weaken, 0)

## Called by the battle after spawning, to scale enemies deeper into a run.
func apply_modifiers(hp_scale: float, damage_bonus: int = 0, name_override: String = "") -> void:
	max_hp = roundi(max_hp * hp_scale)
	current_hp = max_hp
	min_damage += damage_bonus
	max_damage += damage_bonus
	if name_override != "":
		enemy_name = name_override

func is_dead() -> bool:
	return current_hp <= 0

## Plays the death animation and stays on the last frame.
## The battle scene is responsible for cleaning up.
func die():
	anim.play(Constants.ANIM_DEAD)
	await anim.animation_finished

func play_hurt():
	anim.play(Constants.ANIM_HURT)
	await anim.animation_finished
	anim.play(Constants.ANIM_IDLE)
	
func play_attack():
	anim.play(Constants.ANIM_ATTACK)
	await anim.animation_finished
	anim.play(Constants.ANIM_IDLE)

## Performs the planned attack; weaken is used up by it.
func attack() -> int:
	var damage := planned_damage()
	weaken = 0
	return damage
