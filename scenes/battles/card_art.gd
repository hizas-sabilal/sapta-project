extends Control
class_name CardArt
## Procedural card illustration: draws icons for the card's effects, so the art
## always matches what the card does. The first effect is drawn large in the
## middle; any extra effects get small badges along the bottom.

enum Icon { SWORD, SWORDS, BIG_SWORD, SHIELD, HEAL, DRAIN, BLEED, WEAKEN, EXPOSE }

const STEEL := Color(0.86, 0.89, 0.95)
const GOLD := Color(0.95, 0.78, 0.35)
const BLOOD := Color(0.86, 0.12, 0.16)
const SHIELD_BLUE := Color(0.45, 0.68, 1.0)
const HEAL_GREEN := Color(0.55, 0.95, 0.6)
const CURSE := Color(0.82, 0.6, 1.0)

var data: CardData
var tint := Color.WHITE

static func icons_for(card: CardData) -> Array[int]:
	var icons: Array[int] = []
	if card.damage > 0:
		if card.lifesteal > 0:
			icons.append(Icon.DRAIN)
		elif card.hits > 1:
			icons.append(Icon.SWORDS)
		elif card.damage >= 10:
			icons.append(Icon.BIG_SWORD)
		else:
			icons.append(Icon.SWORD)
	if card.block > 0:
		icons.append(Icon.SHIELD)
	if card.heal > 0:
		icons.append(Icon.HEAL)
	if card.bleed > 0:
		icons.append(Icon.BLEED)
	if card.weaken > 0:
		icons.append(Icon.WEAKEN)
	if card.expose > 0:
		icons.append(Icon.EXPOSE)
	# Defense cards lead with the shield, even if they also hit.
	if card.type == CardData.Type.DEFENSE and icons.has(Icon.SHIELD):
		icons.erase(Icon.SHIELD)
		icons.push_front(Icon.SHIELD)
	return icons

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# Backdrop: a dark vignette of the card's color with a soft glow behind the icon.
	draw_rect(r, tint.darkened(0.72))
	var c := size / 2.0
	for i in 4:
		draw_circle(c, size.y * (0.46 - i * 0.08), Color(tint, 0.10 + i * 0.05))
	if data == null:
		return
	var icons := icons_for(data)
	if icons.is_empty():
		return
	_draw_icon(icons[0], c, size.y * 0.36, data.hits)
	# Secondary effects: small badges in the bottom corners.
	for i in range(1, icons.size()):
		var bc := Vector2(size.x - 18 - (i - 1) * 30, size.y - 16)
		draw_circle(bc, 13, Color(0, 0, 0, 0.55))
		draw_arc(bc, 13, 0, TAU, 24, Color(tint, 0.9), 1.5, true)
		_draw_icon(icons[i], bc, 9.0, 1)

func _draw_icon(icon: int, at: Vector2, s: float, hits: int) -> void:
	match icon:
		Icon.SWORD:
			_sword(at, s, 0.6, STEEL)
		Icon.BIG_SWORD:
			_sword(at, s * 1.2, 0.6, GOLD)
		Icon.SWORDS:
			var n := clampi(hits, 2, 4)
			for i in n:
				var t := (i - (n - 1) / 2.0)
				_sword(at + Vector2(t * s * 0.35, 0), s * 0.85, t * 0.45, STEEL)
		Icon.SHIELD:
			_shield(at, s, SHIELD_BLUE)
		Icon.HEAL:
			_cross(at, s, HEAL_GREEN)
		Icon.DRAIN:
			_heart(at + Vector2(0, s * 0.05), s * 0.9, BLOOD)
			_sword(at, s * 0.9, 0.7, STEEL)
		Icon.BLEED:
			_drop(at, s, BLOOD)
		Icon.WEAKEN:
			_broken_sword(at, s, CURSE)
		Icon.EXPOSE:
			_target(at, s, CURSE)

# ------------------------------------------------------------- Primitives
# Each draws centered on `at`, roughly 2*s tall.

func _sword(at: Vector2, s: float, angle: float, color: Color) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	var w := s * 0.13
	var blade := PackedVector2Array([
		Vector2(0, -s), Vector2(w, -s + w * 2), Vector2(w, s * 0.45),
		Vector2(-w, s * 0.45), Vector2(-w, -s + w * 2)])
	draw_colored_polygon(blade, color)
	draw_line(Vector2(0, -s + w * 2), Vector2(0, s * 0.42), color.darkened(0.25), maxf(1.0, w * 0.4))
	draw_rect(Rect2(-s * 0.36, s * 0.45, s * 0.72, s * 0.11), GOLD)
	draw_rect(Rect2(-w * 0.8, s * 0.56, w * 1.6, s * 0.32), Color(0.45, 0.28, 0.16))
	draw_circle(Vector2(0, s * 0.93), w * 1.1, GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _broken_sword(at: Vector2, s: float, color: Color) -> void:
	# Lower half of a sword with a jagged break, and a falling tip.
	draw_set_transform(at + Vector2(-s * 0.15, s * 0.1), 0.35, Vector2.ONE)
	var w := s * 0.13
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -s * 0.15), Vector2(0, -s * 0.3), Vector2(w * 0.4, -s * 0.12),
		Vector2(w, -s * 0.25), Vector2(w, s * 0.45), Vector2(-w, s * 0.45)]), STEEL)
	draw_rect(Rect2(-s * 0.36, s * 0.45, s * 0.72, s * 0.11), GOLD)
	draw_rect(Rect2(-w * 0.8, s * 0.56, w * 1.6, s * 0.32), Color(0.45, 0.28, 0.16))
	draw_set_transform(at + Vector2(s * 0.45, -s * 0.55), 1.1, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -s * 0.4), Vector2(w, -s * 0.25), Vector2(w, s * 0.1),
		Vector2(0, -s * 0.02), Vector2(-w, s * 0.1), Vector2(-w, -s * 0.25)]), STEEL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Down arrow: weaker.
	_arrow_down(at + Vector2(s * 0.55, s * 0.45), s * 0.38, color)

func _arrow_down(at: Vector2, s: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-s * 0.35, -s), at + Vector2(s * 0.35, -s), at + Vector2(s * 0.35, 0),
		at + Vector2(s * 0.8, 0), at + Vector2(0, s), at + Vector2(-s * 0.8, 0),
		at + Vector2(-s * 0.35, 0)]), color)

func _shield(at: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(at + Vector2(-s * 0.8, -s * 0.8))
	pts.append(at + Vector2(0, -s * 0.95))
	pts.append(at + Vector2(s * 0.8, -s * 0.8))
	for i in range(0, 9): # Curved lower edge down to the point.
		var t := i / 8.0
		pts.append(at + Vector2(s * 0.8 * (1.0 - t), lerpf(-s * 0.1, s, t * t * 0.6 + t * 0.4)))
	for i in range(1, 9):
		var t := 1.0 - i / 8.0
		pts.append(at + Vector2(-s * 0.8 * (1.0 - t), lerpf(-s * 0.1, s, t * t * 0.6 + t * 0.4)))
	draw_colored_polygon(pts, color.darkened(0.35))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(at + (p - at) * 0.78)
	draw_colored_polygon(inner, color)
	draw_line(at + Vector2(0, -s * 0.72), at + Vector2(0, s * 0.72), color.lightened(0.45), s * 0.08)
	draw_line(at + Vector2(-s * 0.6, -s * 0.2), at + Vector2(s * 0.6, -s * 0.2), color.lightened(0.45), s * 0.08)

func _cross(at: Vector2, s: float, color: Color) -> void:
	var a := s * 0.32
	draw_rect(Rect2(at + Vector2(-a, -s * 0.85), Vector2(a * 2, s * 1.7)), color)
	draw_rect(Rect2(at + Vector2(-s * 0.85, -a), Vector2(s * 1.7, a * 2)), color)
	draw_rect(Rect2(at + Vector2(-a * 0.45, -s * 0.7), Vector2(a * 0.9, s * 1.4)), color.lightened(0.5))
	draw_rect(Rect2(at + Vector2(-s * 0.7, -a * 0.45), Vector2(s * 1.4, a * 0.9)), color.lightened(0.5))

func _drop(at: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -s)])
	for i in 17: # Round bottom: from upper-left, under, to upper-right.
		var ang := PI * 0.82 + (PI * 1.36) * i / 16.0
		pts.append(at + Vector2(0, s * 0.35) + Vector2(cos(ang), -sin(ang)) * s * 0.6)
	draw_colored_polygon(pts, color)
	draw_circle(at + Vector2(-s * 0.2, s * 0.3), s * 0.14, color.lightened(0.5))

func _heart(at: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		pts.append(at + Vector2(x, -y) * (s / 17.0))
	draw_colored_polygon(pts, color)

func _target(at: Vector2, s: float, color: Color) -> void:
	draw_arc(at, s * 0.85, 0, TAU, 40, color, s * 0.12, true)
	draw_arc(at, s * 0.45, 0, TAU, 32, color, s * 0.1, true)
	draw_circle(at, s * 0.14, BLOOD)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(at + d * s * 0.6, at + d * s * 1.05, color, s * 0.1)
