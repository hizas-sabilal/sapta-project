extends Node2D

@onready var anim = $AnimatedSprite2D

const max_hp := 15
var hp := 15
var min_damage := 1
var max_damage := 6
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.flip_h = true
	anim.play("idle")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func take_damage(amount: int):
	hp -= amount
	
	print("Vampire HP: ", hp)
	
	if hp <= 0:
		die()

func die():
	anim.play("dead")
	await anim.animation_finished
	queue_free()

func play_hurt():
	anim.play("hurt")
	await anim.animation_finished
	anim.play("idle")
	
func play_attack():
	anim.play("attack")
	await anim.animation_finished
	anim.play("idle")

func attack() -> int:
	return randi_range(min_damage, max_damage)
