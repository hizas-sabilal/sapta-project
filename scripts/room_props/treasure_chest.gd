extends RoomProp
## Chest: opens a card reward once.

var _lid: Polygon2D
var _opened := false

func _build_visual() -> void:
	_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-22, -22), Vector2(22, -22), Vector2(22, 0)]),
		Color(0.45, 0.28, 0.12)) # box
	_lid = _polygon(PackedVector2Array([Vector2(-24, -22), Vector2(-24, -34), Vector2(24, -34), Vector2(24, -22)]),
		Color(0.85, 0.65, 0.2)) # gold lid

func _ready() -> void:
	super._ready()
	label.text = "Chest\n(touch to open)"

func _on_player_entered(_player: Node2D) -> void:
	if _opened:
		return
	_opened = true
	_lid.position = Vector2(0, -10)
	_lid.rotation_degrees = -20
	label.text = "Opened"
	GameManager.open_treasure()
