extends Area2D
class_name RoomProp
## Base for things in a room the player walks into (exit, campfire, chest).
## Builds its own trigger area and a placeholder look, so no art is needed yet;
## swap _build_visual() for a Sprite2D when you have assets.

## Trigger size; the area's origin is its bottom-center, standing on the ground.
@export var trigger_size := Vector2(64, 80)

var label: Label

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = trigger_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -trigger_size.y / 2.0)
	add_child(collision)

	_build_visual()

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.size = Vector2(220, 40)
	label.position = Vector2(-110, -trigger_size.y - 44)
	add_child(label)

	body_entered.connect(func(body):
		if body.is_in_group("player"):
			_on_player_entered(body))

## Override: add placeholder shapes.
func _build_visual() -> void:
	pass

## Override: react to the player touching this prop.
func _on_player_entered(_player: Node2D) -> void:
	pass

## Helper for placeholder visuals: a filled polygon.
func _polygon(points: PackedVector2Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	add_child(poly)
	return poly
