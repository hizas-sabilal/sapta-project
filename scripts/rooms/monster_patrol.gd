extends Node
class_name MonsterPatrol
## Walks its parent monster back and forth between two x positions on flat ground,
## pausing at each end. Movement is kinematic (no physics): the patrol range is
## computed from the room layout, so the ground is known to be flat the whole way.
## Touching the player still starts a battle through the monster's BattleTrigger.

@export var speed := 45.0
@export var pause_min := 0.4
@export var pause_max := 1.2

var left_x := 0.0
var right_x := 0.0

var _monster: Node2D
var _sprite: AnimatedSprite2D
var _dir := 1.0
var _pause := 0.0

## Call before adding the patrol to the monster.
func setup(from_x: float, to_x: float, start_dir: float) -> void:
	left_x = minf(from_x, to_x)
	right_x = maxf(from_x, to_x)
	_dir = 1.0 if start_dir >= 0.0 else -1.0

func _ready() -> void:
	_monster = get_parent() as Node2D
	_sprite = _monster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_face()

func _physics_process(delta: float) -> void:
	if right_x - left_x < 1.0:
		return # No room to walk: stand guard.
	if _pause > 0.0:
		_pause -= delta
		return
	var x := _monster.position.x + _dir * speed * delta
	if x <= left_x or x >= right_x:
		x = clampf(x, left_x, right_x)
		_dir = -_dir
		_pause = randf_range(pause_min, pause_max)
		_face()
	_monster.position.x = x

func _face() -> void:
	if _sprite:
		_sprite.flip_h = _dir < 0.0
