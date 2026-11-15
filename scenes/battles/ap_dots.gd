extends Control
class_name ApDots
## Action points as a row of radio-button dots: a filled dot is an AP you can
## still spend, an empty ring is one already committed to selected cards.

const RADIUS := 11.0
const GAP := 8.0
const RING := Color(0.98, 0.82, 0.35)
const FILL := Color(1.0, 0.88, 0.45)
const EMPTY_RING := Color(0.5, 0.45, 0.35)

var total := 3
var available := 3

func set_values(available_ap: int, total_ap: int) -> void:
	available = available_ap
	total = total_ap
	custom_minimum_size = Vector2(total * (RADIUS * 2 + GAP) - GAP, RADIUS * 2)
	queue_redraw()

func _draw() -> void:
	for i in total:
		var c := Vector2(RADIUS + i * (RADIUS * 2 + GAP), RADIUS)
		var lit := i < available
		draw_circle(c, RADIUS, Color(0, 0, 0, 0.55))
		draw_arc(c, RADIUS - 1.5, 0, TAU, 32, RING if lit else EMPTY_RING, 2.5, true)
		if lit:
			draw_circle(c, RADIUS * 0.55, FILL)
			draw_circle(c + Vector2(-2, -2), RADIUS * 0.18, Color(1, 1, 1, 0.7))
