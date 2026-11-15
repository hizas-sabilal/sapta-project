extends RoomProp
## Rest spot: heals once (RunManager.REST_HEAL_FRACTION of max HP).

var _flame: Polygon2D
var _used := false

func _build_visual() -> void:
	_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-16, -8), Vector2(16, -8), Vector2(22, 0)]),
		Color(0.4, 0.25, 0.12)) # logs
	_flame = _polygon(PackedVector2Array([Vector2(-14, -8), Vector2(0, -44), Vector2(14, -8)]),
		Color(1.0, 0.55, 0.1))

func _ready() -> void:
	super._ready()
	label.text = "Campfire\n(touch to rest)"

func _process(_delta: float) -> void:
	if not _used:
		# Cheap flicker.
		_flame.scale.y = 1.0 + sin(Time.get_ticks_msec() / 90.0) * 0.12

func _on_player_entered(_player: Node2D) -> void:
	if _used:
		return
	_used = true
	var healed := RunManager.rest()
	label.text = "Rested: +%d HP" % healed
	_flame.color = Color(0.35, 0.35, 0.35)
	_flame.scale = Vector2(0.6, 0.4)
