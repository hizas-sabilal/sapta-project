extends Node2D

@onready var anim = $AnimatedSprite2D

## Set from RunManager by the battle scene via setup().
var max_hp := 30
var hp := 30
var block := 0

func setup(current_hp: int, maximum_hp: int) -> void:
	hp = current_hp
	max_hp = maximum_hp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.play("idle")

func play_attack():
	anim.play("attack")
	await anim.animation_finished
	anim.play("idle")

func play_hurt():
	anim.play("hurt")
	await anim.animation_finished
	anim.play("idle")

## Block absorbs damage first, then the rest hits HP. Returns the HP lost.
func take_damage(damage: int) -> int:
	var absorbed: int = min(block, damage)
	block -= absorbed
	var lost: int = min(damage - absorbed, hp)
	hp -= lost
	print("PLAYER took ", damage, " (blocked ", absorbed, ") -> HP ", hp)
	return lost

func add_block(amount: int):
	block += amount
	print("PLAYER BLOCK:", block)

func reset_block():
	block = 0

## Returns the HP actually restored (capped at max HP).
func heal(amount: int) -> int:
	var restored: int = min(amount, max_hp - hp)
	hp += restored
	print("PLAYER HEALED FOR:", restored, " -> HP ", hp)
	return restored

func is_dead() -> bool:
	return hp <= 0

## Plays the death animation and stays on the last frame.
func die():
	print("PLAYER DEAD")
	anim.play("dead")
	await anim.animation_finished
