extends RoomProp
## Door at the end of a room. Locked while any node in the "room_guard" group
## (the room's monster) is still in the level.

const LOCKED_COLOR := Color(0.55, 0.15, 0.15, 0.85)
const OPEN_COLOR := Color(0.2, 0.55, 0.3, 0.85)

var _door: Polygon2D

func _build_visual() -> void:
	var w := trigger_size.x / 2.0
	var h := trigger_size.y
	_door = _polygon(PackedVector2Array([
		Vector2(-w, 0), Vector2(-w, -h * 0.75), Vector2(0, -h), Vector2(w, -h * 0.75), Vector2(w, 0)
	]), LOCKED_COLOR)

func is_locked() -> bool:
	return not get_tree().get_nodes_in_group("room_guard").is_empty()

func _process(_delta: float) -> void:
	var locked := is_locked()
	_door.color = LOCKED_COLOR if locked else OPEN_COLOR
	label.text = "Defeat the monster\nto open" if locked else "Exit"

func _on_player_entered(_player: Node2D) -> void:
	if not is_locked():
		GameManager.reach_exit()
