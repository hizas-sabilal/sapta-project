extends Camera2D
class_name RoomCamera
## Attached to the player and follows her, clamped to the room's bounds.
## Leans slightly ahead in the direction she's running.

@export var look_ahead := 60.0
@export var look_ahead_speed := 3.0
@export var follow_speed := 10.0 ## Higher = tighter follow.

## room_rect is in GLOBAL coordinates (camera limits are global).
func setup(room_rect: Rect2) -> void:
	limit_left = int(room_rect.position.x)
	limit_top = int(room_rect.position.y)
	limit_right = int(room_rect.end.x)
	limit_bottom = int(room_rect.end.y)

func _ready() -> void:
	position = Vector2.ZERO
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed

func _enter_tree() -> void:
	# Also runs when the level comes back after a battle.
	make_current.call_deferred()
	reset_smoothing.call_deferred() # Snap to Iris instead of sliding in from elsewhere.

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	if body == null:
		return
	var target := 0.0
	if absf(body.velocity.x) > 20.0:
		target = signf(body.velocity.x) * look_ahead
	# Moving the camera's own position (not offset) keeps it inside the limits.
	position.x = lerpf(position.x, target, minf(look_ahead_speed * delta, 1.0))
