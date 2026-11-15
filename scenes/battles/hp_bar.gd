extends Control
class_name HpBar
## Health bar: the fill eases to the new value and a pale "recent damage" trail
## catches up behind it. Color goes green -> yellow -> red as HP drops.
## With block > 0 a shield badge with the amount sits at the bar's left end.

const BG := Color(0.08, 0.08, 0.1, 0.9)
const TRAIL := Color(1.0, 0.92, 0.8, 0.85)
const SHIELD := Color(0.45, 0.68, 1.0)
const HIGH := Color(0.3, 0.82, 0.4)
const MID := Color(0.95, 0.78, 0.25)
const LOW := Color(0.9, 0.25, 0.2)

var hp := 1
var max_hp := 1
var block := 0

var _shown := 1.0 ## Displayed fill fraction (eased).
var _trail := 1.0 ## Trailing fraction showing recent damage.
var _font: Font
var _initialized := false

func _ready() -> void:
	_font = get_theme_default_font()
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(260, 26)

func set_values(new_hp: int, new_max: int, new_block: int = 0) -> void:
	hp = new_hp
	max_hp = maxi(new_max, 1)
	block = new_block
	if not _initialized: # Don't animate the initial fill.
		_initialized = true
		_shown = _fraction()
		_trail = _shown
	queue_redraw()

func _fraction() -> float:
	return clampf(float(hp) / max_hp, 0.0, 1.0)

func _process(delta: float) -> void:
	var target := _fraction()
	var before := Vector2(_shown, _trail)
	_shown = move_toward(_shown, target, delta * 2.5)
	if _trail < _shown: # Healing: trail snaps up with the fill.
		_trail = _shown
	elif _shown <= target + 0.001: # Damage: trail drains after the fill settles.
		_trail = move_toward(_trail, _shown, delta * 0.8)
	if before != Vector2(_shown, _trail):
		queue_redraw()

func _draw() -> void:
	var bar := Rect2(Vector2.ZERO, size)
	var inner := bar.grow(-3)
	_rounded(bar, BG, 6)
	if _trail > _shown:
		_rounded(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), TRAIL, 4)
	if _shown > 0.0:
		var f := _fraction()
		var color := LOW.lerp(MID, clampf(f * 2.0, 0, 1)) if f < 0.5 else MID.lerp(HIGH, (f - 0.5) * 2.0)
		var fill := Rect2(inner.position, Vector2(inner.size.x * _shown, inner.size.y))
		_rounded(fill, color, 4)
		# Glossy top highlight.
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.35)), Color(1, 1, 1, 0.18))
	draw_rect(bar, Color(0, 0, 0, 0.85), false, 2.0)

	var text := "%d / %d" % [hp, max_hp]
	var fs := int(size.y * 0.62)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((size.x - tw) / 2.0, size.y / 2.0 + fs * 0.36)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	if block > 0:
		_draw_block_badge(Vector2(-4, size.y / 2.0))

func _draw_block_badge(at: Vector2) -> void:
	var s := size.y * 0.75
	var pts := PackedVector2Array([
		at + Vector2(-s, -s), at + Vector2(s, -s), at + Vector2(s, -s * 0.1),
		at + Vector2(s * 0.6, s * 0.6), at + Vector2(0, s * 1.05),
		at + Vector2(-s * 0.6, s * 0.6), at + Vector2(-s, -s * 0.1)])
	draw_colored_polygon(pts, SHIELD.darkened(0.4))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(at + (p - at) * 0.8)
	draw_colored_polygon(inner, SHIELD)
	var text := str(block)
	var fs := int(s * 1.05)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := at + Vector2(-tw / 2.0, fs * 0.32)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.1, 0.25))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _rounded(r: Rect2, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)
