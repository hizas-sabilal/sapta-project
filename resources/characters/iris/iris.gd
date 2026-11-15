extends CharacterBody2D
## Exploration movement for Iris.
## Every value is exported, so you can tune the feel in the Inspector while the game runs.

@export_group("Run")
@export var max_speed := 110.0
## How fast Iris reaches full speed on the ground (px/s²).
@export var acceleration := 900.0
## How fast Iris stops on the ground when no key is held (px/s²).
@export var friction := 1200.0
@export var air_acceleration := 650.0
@export var air_friction := 300.0

@export_group("Jump")
@export var jump_velocity := -400.0
## Releasing jump early multiplies upward speed by this: tap = short hop, hold = full jump.
@export var jump_cut_multiplier := 0.45
## Falling is faster than rising, which feels less floaty.
@export var fall_gravity_multiplier := 1.6
@export var max_fall_speed := 650.0
## Grace period to still jump after walking off a ledge (seconds).
@export var coyote_time := 0.1
## Pressing jump slightly before landing still jumps on landing (seconds).
@export var jump_buffer_time := 0.12

@export_group("Juice")
## Sprite stretch on jump / squash on land. Set to 0 to disable.
@export var squash_amount := 0.18
@export var squash_recovery := 12.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _was_on_floor := true

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# Timers for forgiving jumps.
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	if Input.is_action_just_pressed("Move up"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	# Gravity (heavier while falling).
	if not on_floor:
		var gravity := get_gravity()
		if velocity.y > 0.0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	# Jump.
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_squash(Vector2(1.0 - squash_amount, 1.0 + squash_amount))

	# Variable jump height.
	if Input.is_action_just_released("Move up") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	# Horizontal movement with acceleration instead of instant speed.
	var direction := Input.get_axis("Move left", "Move right")
	if direction != 0.0:
		var accel := acceleration if on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, direction * max_speed, accel * delta)
	else:
		var decel := friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	move_and_slide()

	# Landing squash.
	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.0 + squash_amount, 1.0 - squash_amount))
	_was_on_floor = is_on_floor()

	_update_animation(direction, delta)

func _update_animation(direction: float, delta: float) -> void:
	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if absf(velocity.x) > 10.0:
		sprite.play("run")
		# Legs speed up as Iris speeds up, so starting/stopping doesn't look like sliding.
		sprite.speed_scale = clampf(absf(velocity.x) / max_speed, 0.5, 1.0)
	else:
		sprite.play("Idle")
		sprite.speed_scale = 1.0

	sprite.scale = sprite.scale.lerp(Vector2.ONE, minf(squash_recovery * delta, 1.0))

func _squash(target_scale: Vector2) -> void:
	if squash_amount > 0.0:
		sprite.scale = target_scale
