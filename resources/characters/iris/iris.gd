extends CharacterBody2D
## Exploration movement for Iris, tuned for a metroidvania feel:
## fast acceleration, a snappy jump defined by height/time, wall slide + wall jump,
## and an air dash. Every value is exported: tune it in the Inspector while playing.

@export_group("Run")
@export var max_speed := 230.0
@export var acceleration := 1800.0 ## Ground, px/s².
@export var friction := 2400.0 ## Ground slowdown with no input, px/s².
@export var air_acceleration := 1400.0
@export var air_friction := 900.0

@export_group("Jump")
## Peak height of a full (held) jump, px. 160 = 2.5 blocks.
@export var jump_height := 160.0
## Seconds to reach the peak. Lower = snappier.
@export var time_to_apex := 0.38
## Falling is faster than rising, which feels less floaty.
@export var fall_gravity_multiplier := 1.5
@export var max_fall_speed := 900.0
## Releasing jump early multiplies upward speed by this: tap = short hop.
@export var jump_cut_multiplier := 0.4
## Grace period to still jump after walking off a ledge (seconds).
@export var coyote_time := 0.1
## Jump pressed slightly before landing still counts (seconds).
@export var jump_buffer_time := 0.12

@export_group("Wall")
## Max fall speed while holding toward a wall.
@export var wall_slide_speed := 140.0
@export var wall_jump_push := 260.0 ## Horizontal kick away from the wall.
@export var wall_jump_height_ratio := 0.85 ## Fraction of a normal jump's upward speed.
## Steering is locked briefly after a wall jump so the kick isn't cancelled instantly.
@export var wall_jump_lock_time := 0.16
@export var wall_coyote_time := 0.08

@export_group("Dash")
@export var dash_speed := 620.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.35
@export var afterimage_interval := 0.03

@export_group("Hurt")
## Seconds of invulnerability after taking damage (Iris blinks meanwhile).
@export var hurt_invulnerability := 1.0
## Upward bounce when hurt, as a fraction of a full jump's speed.
@export var hurt_bounce_ratio := 0.75
@export var hurt_push := 200.0 ## Horizontal knockback, px/s.
@export var hurt_control_lock := 0.2 ## Steering is locked briefly so the knockback reads.

@export_group("Juice")
## Sprite stretch on jump / squash on land. Set to 0 to disable.
@export var squash_amount := 0.18
@export var squash_recovery := 12.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _gravity := 0.0
var _jump_velocity := 0.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_coyote_timer := 0.0
var _wall_normal_x := 0.0
var _control_lock_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := 1.0
var _can_dash := true
var _afterimage_timer := 0.0
var _was_on_floor := true
var _invuln_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	_recalculate_jump()

## Derives gravity and jump speed from jump_height / time_to_apex.
## Call again after changing those two at runtime.
func _recalculate_jump() -> void:
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = -2.0 * jump_height / time_to_apex

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var on_wall := is_on_wall_only()
	var direction := Input.get_axis("Move left", "Move right")

	_tick_timers(delta, on_floor, on_wall)

	if Input.is_action_just_pressed("Dash") and _can_dash and _dash_cooldown_timer <= 0.0:
		_start_dash(direction)

	if _dash_timer > 0.0:
		_process_dash(delta)
	else:
		_apply_gravity(delta, on_floor, on_wall, direction)
		_handle_jump(on_floor)
		_apply_horizontal(delta, on_floor, direction)
		move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.0 + squash_amount, 1.0 - squash_amount))
	_was_on_floor = is_on_floor()

	_update_animation(direction, on_wall, delta)
	_update_invulnerability(delta)

## Called by traps. Takes HP from the run, knocks Iris up and away from
## `from_x`, and makes her briefly invulnerable. Ignored while invulnerable.
func hurt(amount: int, from_x: float) -> void:
	if _invuln_timer > 0.0 or RunManager.hp <= 0:
		return
	RunManager.hp = maxi(RunManager.hp - amount, 0)
	_invuln_timer = hurt_invulnerability
	_popup("-%d" % amount)

	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = 1.0 if sprite.flip_h else -1.0 # Back the way she was facing from.
	_dash_timer = 0.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	velocity = Vector2(away * hurt_push, _jump_velocity * hurt_bounce_ratio)
	_control_lock_timer = hurt_control_lock
	sprite.modulate = Color(1.0, 0.45, 0.45)

	if RunManager.hp <= 0:
		GameManager.player_killed()

func _update_invulnerability(delta: float) -> void:
	if _invuln_timer <= 0.0:
		return
	_invuln_timer -= delta
	if _invuln_timer <= 0.0:
		sprite.modulate = Color.WHITE
	else:
		# Blink, fading the red hit tint back to normal.
		var tint := Color.WHITE.lerp(Color(1.0, 0.45, 0.45), _invuln_timer / hurt_invulnerability)
		tint.a = 0.35 if int(_invuln_timer * 14.0) % 2 == 0 else 1.0
		sprite.modulate = tint

## Floating damage number above Iris.
func _popup(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.z_index = 10
	get_parent().add_child(label)
	label.position = position - Vector2(label.get_combined_minimum_size().x / 2.0, 80)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

func _tick_timers(delta: float, on_floor: bool, on_wall: bool) -> void:
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	if Input.is_action_just_pressed("Move up"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta
	if on_wall:
		_wall_coyote_timer = wall_coyote_time
		_wall_normal_x = get_wall_normal().x
	else:
		_wall_coyote_timer -= delta
	_control_lock_timer -= delta
	_dash_cooldown_timer -= delta
	if on_floor:
		_can_dash = true

func _apply_gravity(delta: float, on_floor: bool, on_wall: bool, direction: float) -> void:
	if on_floor:
		return
	var gravity := _gravity
	if velocity.y > 0.0:
		gravity *= fall_gravity_multiplier
	velocity.y += gravity * delta

	var fall_cap := max_fall_speed
	var pushing_into_wall := on_wall and direction != 0.0 and signf(direction) == -signf(_wall_normal_x)
	if pushing_into_wall:
		fall_cap = wall_slide_speed
	velocity.y = minf(velocity.y, fall_cap)

func _handle_jump(on_floor: bool) -> void:
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			velocity.y = _jump_velocity
			_consume_jump()
		elif _wall_coyote_timer > 0.0 and not on_floor:
			velocity = Vector2(_wall_normal_x * wall_jump_push, _jump_velocity * wall_jump_height_ratio)
			_control_lock_timer = wall_jump_lock_time
			_wall_coyote_timer = 0.0
			_can_dash = true # Wall jumps refresh the air dash.
			sprite.flip_h = _wall_normal_x < 0.0
			_consume_jump()

	# Variable jump height.
	if Input.is_action_just_released("Move up") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

func _consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_squash(Vector2(1.0 - squash_amount, 1.0 + squash_amount))

func _apply_horizontal(delta: float, on_floor: bool, direction: float) -> void:
	if _control_lock_timer > 0.0:
		return # Keep the wall-jump kick.
	if direction != 0.0:
		var accel := acceleration if on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, direction * max_speed, accel * delta)
	else:
		var decel := friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

func _start_dash(direction: float) -> void:
	_dash_dir = signf(direction) if direction != 0.0 else (-1.0 if sprite.flip_h else 1.0)
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	_afterimage_timer = 0.0
	if not is_on_floor():
		_can_dash = false # One air dash until you land or wall jump.
	sprite.flip_h = _dash_dir < 0.0
	_squash(Vector2(1.0 + squash_amount, 1.0 - squash_amount * 0.5))

## Straight horizontal burst, no gravity.
func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity = Vector2(_dash_dir * dash_speed, 0.0)
	move_and_slide()
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = afterimage_interval
		_spawn_afterimage()
	if _dash_timer <= 0.0 or is_on_wall():
		_dash_timer = 0.0
		velocity.x = _dash_dir * max_speed # Exit at run speed, not dash speed.

## A fading copy of the current frame left behind while dashing.
func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.modulate = Color(0.6, 0.8, 1.0, 0.5)
	ghost.z_index = sprite.z_index
	# Add to the tree first: global_transform only resolves correctly once the
	# ghost has a parent, otherwise the parent's offset gets applied twice.
	get_parent().add_child(ghost)
	ghost.global_transform = sprite.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)

func _update_animation(direction: float, on_wall: bool, delta: float) -> void:
	if _dash_timer <= 0.0 and _control_lock_timer <= 0.0 and direction != 0.0:
		sprite.flip_h = direction < 0.0
	if on_wall and not is_on_floor() and velocity.y > 0.0:
		sprite.flip_h = _wall_normal_x < 0.0 # Face away from the wall while sliding.

	if absf(velocity.x) > 10.0 and is_on_floor():
		sprite.play("run")
		# Legs speed up as Iris speeds up, so starting/stopping doesn't look like sliding.
		sprite.speed_scale = clampf(absf(velocity.x) / max_speed, 0.5, 1.0)
	elif is_on_floor():
		sprite.play("Idle")
		sprite.speed_scale = 1.0
	else:
		# No jump art yet: hold a running frame in the air.
		sprite.play("run")
		sprite.speed_scale = 0.0

	sprite.scale = sprite.scale.lerp(Vector2.ONE, minf(squash_recovery * delta, 1.0))

func _squash(target_scale: Vector2) -> void:
	if squash_amount > 0.0:
		sprite.scale = target_scale
