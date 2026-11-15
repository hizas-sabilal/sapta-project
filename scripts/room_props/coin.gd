extends Area2D
class_name Coin
## A coin floating above the ground. Touching it adds `value` coins to the
## permanent bank (Progress), which is saved straight away.
## Placeholder art drawn in code.

const RADIUS := 11.0
const BOB_HEIGHT := 4.0
const BOB_SPEED := 3.0

const GOLD := Color(1.0, 0.82, 0.25)
const GOLD_DARK := Color(0.72, 0.5, 0.1)
const SHINE := Color(1.0, 0.97, 0.8)

var value := 1 ## Every coin is worth exactly 1.
var _collected := false
var _time := 0.0
var _base_y := 0.0

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS + 4.0 # A little generous so brushing past counts.
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	_base_y = position.y
	_time = randf() * TAU # Coins in a row don't bob in sync.
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
	# Fake spin: squash horizontally.
	scale.x = 0.55 + 0.45 * absf(cos(_time * 2.0))

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, GOLD_DARK)
	draw_circle(Vector2.ZERO, RADIUS - 2.5, GOLD)
	draw_rect(Rect2(-1.5, -5, 3, 10), GOLD_DARK)
	draw_circle(Vector2(-3.5, -4), 2.0, SHINE)

func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	Progress.add_coins(value)
	scale = Vector2.ONE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 40, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
