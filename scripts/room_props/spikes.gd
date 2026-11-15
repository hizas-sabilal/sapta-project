extends Area2D
class_name Spikes
## A strip of floor spikes. Touching them hurts Iris (RunManager HP), bounces
## her up and gives her a moment of invulnerability. They don't block movement:
## she can always jump over them, and if she lands on them she's bounced off.
##
## Origin is the strip's bottom-left corner, standing on the ground.
## Placeholder art drawn in code; swap _draw() for a Sprite2D when there's art.

const SPIKE_WIDTH := 16.0
const SPIKE_HEIGHT := 20.0
## Hitbox is lower and narrower than the art, so grazing a tip doesn't count.
const HITBOX_HEIGHT := 12.0
const HITBOX_INSET := 6.0

const STEEL := Color(0.74, 0.76, 0.82)
const STEEL_SHADE := Color(0.45, 0.47, 0.54)
const BASE := Color(0.2, 0.2, 0.24)
const TIP := Color(0.75, 0.2, 0.2)

var width := 64.0
var damage := 3

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width - HITBOX_INSET * 2.0, HITBOX_HEIGHT)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(width / 2.0, -HITBOX_HEIGHT / 2.0)
	add_child(collision)

## Checked every physics frame (not just on entry) so standing in the spikes
## keeps hurting once the invulnerability wears off.
func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("hurt"):
			body.hurt(damage, global_position.x + width / 2.0)

func _draw() -> void:
	draw_rect(Rect2(0, -4, width, 4), BASE)
	var count := int(width / SPIKE_WIDTH)
	for i in count:
		var left := i * SPIKE_WIDTH
		var tip := Vector2(left + SPIKE_WIDTH / 2.0, -SPIKE_HEIGHT)
		# Lit left face, shaded right face, red tip.
		draw_colored_polygon(PackedVector2Array([Vector2(left, -3), tip, Vector2(tip.x, -3)]), STEEL)
		draw_colored_polygon(PackedVector2Array([Vector2(tip.x, -3), tip, Vector2(left + SPIKE_WIDTH, -3)]), STEEL_SHADE)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-2.5, 6), tip + Vector2(2.5, 6)]), TIP)
