extends Area2D
class_name AmmoBox
## A box of rounds on the ground. Touching it adds the equipped gun's
## `ammo_per_pickup` to the run's spare rounds (RunManager.pick_up_ammo()).
## Only placed while a gun is equipped. Placeholder art drawn in code.

const SIZE := Vector2(30, 20)
const OLIVE := Color(0.33, 0.38, 0.2)
const OLIVE_DARK := Color(0.2, 0.24, 0.12)
const BRASS := Color(0.9, 0.7, 0.32)

var _collected := false
var _time := 0.0

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SIZE + Vector2(10, 10) # A little generous so walking past counts.
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -SIZE.y / 2.0)
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	queue_redraw() # The glint pulses.

## Drawn with its bottom edge on the origin (the ground).
func _draw() -> void:
	var box := Rect2(Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)
	draw_rect(box, OLIVE_DARK)
	draw_rect(box.grow(-2), OLIVE)
	draw_rect(Rect2(box.position + Vector2(0, 5), Vector2(SIZE.x, 3)), OLIVE_DARK) # lid seam
	# Stencilled cartridges on the side.
	for i in 3:
		var x := -9.0 + i * 7.0
		draw_rect(Rect2(x, -12, 4, 8), BRASS)
		draw_circle(Vector2(x + 2, -12), 2.0, BRASS.lightened(0.3))
	var glint := 0.35 + 0.35 * (sin(_time * 3.0) + 1.0) / 2.0
	draw_circle(Vector2(-10, -16), 2.0, Color(1, 1, 0.85, glint))

func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	var added := RunManager.pick_up_ammo()
	if added > 0:
		UiManager.show_toast("Ammo!  +%d %s rounds" % [added, RunManager.weapon.weapon_name])
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
