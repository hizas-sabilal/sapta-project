extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var sprite = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# Add gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if (Input.is_action_just_pressed("Move up") and is_on_floor()):
		velocity.y = JUMP_VELOCITY

	# Horizontal movement.
	var direction := Input.get_axis("Move left", "Move right")

	if direction:
		velocity.x = direction * SPEED

		# Flip sprite
		if direction < 0:
			sprite.flip_h = true
		elif direction > 0:
			sprite.flip_h = false

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _on_battle_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.enter_battle()
