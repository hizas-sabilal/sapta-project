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

func take_damage(amount: int):
	current_hp = max(current_hp - amount, 0)
	print(enemy_name, " HP : ", current_hp)

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

func attack() -> int:
	return randi_range(min_damage, max_damage)
