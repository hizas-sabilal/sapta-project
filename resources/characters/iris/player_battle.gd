extends Node2D

@onready var anim = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.play("idle")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func play_attack():
	anim.play("attack")
	await anim.animation_finished
	anim.play("idle")

func play_hurt():
	anim.play("hurt")
	await anim.animation_finished
	anim.play("idle")
