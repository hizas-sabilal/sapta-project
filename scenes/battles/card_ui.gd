extends Panel
## A card in the hand or on a reward screen. Built in code from its CardData:
## a frame in the card type's color, cost gem, procedural art (CardArt) that
## shows the card's effects, a type ribbon, the generated rules text and flavor.
##
## The root keeps its slot in the parent container; only the inner body moves,
## so hover / selected lifts aren't undone when the container re-sorts.

## Emitted with this card when left-clicked. Whoever spawns the card decides
## what a click means (select in hand, pick as reward, ...).
signal clicked(card)

const CARD_SIZE := Vector2(170, 250)
const LIFT_ROOM := 22.0 ## Space above the card so a selected card can rise in place.
const HOVER_LIFT := 8.0

const TYPE_COLORS := {
	CardData.Type.ATTACK: Color(0.86, 0.27, 0.22),
	CardData.Type.DEFENSE: Color(0.27, 0.52, 0.92),
	CardData.Type.HEAL: Color(0.3, 0.74, 0.42),
	CardData.Type.DEBUFF: Color(0.62, 0.38, 0.88),
	CardData.Type.UTILITY: Color(0.78, 0.6, 0.28),
}
const BRASS := Color(0.9, 0.7, 0.32)
const EMPTY_COLOR := Color(1.0, 0.45, 0.35)
const SELECTED_BORDER := Color(1.0, 0.85, 0.3)
const FOCUS_BORDER := Color(1.0, 1.0, 1.0)

@export var data: CardData

var selected := false
var _hovered := false
var _focused := false ## Keyboard cursor is on this card.
var _playable := true

var _spent := false ## Already resolved this turn; waits to be discarded.

var _body: Panel
var _frame_style: StyleBoxFlat
var _order_badge: Panel
var _order_label: Label
var _trigger_tween: Tween
var _empty_tag: Label ## "RELOAD" / "EMPTY": this gun card can't fire right now (see set_shot()).
var _ammo_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = CARD_SIZE + Vector2(0, LIFT_ROOM)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	if data:
		_build()
	_update_look()

func _build() -> void:
	var color: Color = TYPE_COLORS.get(data.type, Color.GRAY)

	_body = Panel.new()
	_body.size = CARD_SIZE
	_body.pivot_offset = CARD_SIZE / 2.0 # Trigger shake scales / tilts around the center.
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = color.darkened(0.78)
	_frame_style.set_border_width_all(3)
	_frame_style.border_color = color
	_frame_style.set_corner_radius_all(10)
	_frame_style.shadow_color = Color(0, 0, 0, 0.5)
	_frame_style.shadow_size = 6
	_frame_style.shadow_offset = Vector2(0, 3)
	_body.add_theme_stylebox_override("panel", _frame_style)
	add_child(_body)

	# Name across the top, right of the cost gem.
	# Long names still fit (gun cards have less room: the ammo badge takes a corner).
	var name_size := 17 if data.card_name.length() <= (8 if data.ammo > 0 else 12) else 14
	var name_label := _label(data.card_name, name_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(36, 8)
	# Leave the top-right corner to the ammo badge on gun cards.
	name_label.size = Vector2(CARD_SIZE.x - (72 if data.ammo > 0 else 44), 26)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_body.add_child(name_label)

	# Illustration.
	var art := CardArt.new()
	art.data = data
	art.tint = color
	art.position = Vector2(10, 40)
	art.size = Vector2(CARD_SIZE.x - 20, 92)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	_body.add_child(art)

	# Type ribbon under the art.
	var ribbon := Panel.new()
	ribbon.position = Vector2(10, 134)
	ribbon.size = Vector2(CARD_SIZE.x - 20, 18)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = color.darkened(0.35)
	if data.is_rare(): # Gold-trimmed ribbon marks rare cards.
		ribbon_style.set_border_width_all(2)
		ribbon_style.border_color = SELECTED_BORDER
	ribbon_style.set_corner_radius_all(4)
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	_body.add_child(ribbon)
	var ribbon_text := data.type_name().to_upper() + ("  -  RARE" if data.is_rare() else "")
	if data.ammo > 0: # Gun art already says "attack"; the rounds matter more (and fit).
		ribbon_text = ("RARE  -  " if data.is_rare() else "") + data.ammo_text().to_upper()
	var type_label := _label(ribbon_text, 11, color.lightened(0.6), HORIZONTAL_ALIGNMENT_CENTER)
	type_label.size = ribbon.size
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(type_label)

	# Rules text, generated from the card's effects.
	var text := data.rules_text()
	var rules_size := 14 if text.length() <= 30 else 13 # Long rules shrink to stay clear of the flavor.
	var rules := _label(text, rules_size, Color(0.95, 0.95, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	# Wrap before sizing: an unwrapped label first grows to fit its whole line.
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rules.position = Vector2(8, 155)
	rules.size = Vector2(CARD_SIZE.x - 16, 58)
	_body.add_child(rules)

	if data.description != "":
		var flavor := _label(data.description, 10, Color(0.68, 0.68, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		flavor.position = Vector2(10, 215)
		flavor.size = Vector2(CARD_SIZE.x - 20, 30)
		_body.add_child(flavor)

	# Cost gem in the top-left corner (drawn last so it sits over the frame).
	var gem := Panel.new()
	gem.position = Vector2(-6, -6)
	gem.size = Vector2(38, 38)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem_style := StyleBoxFlat.new()
	gem_style.bg_color = Color(0.98, 0.8, 0.3)
	gem_style.set_corner_radius_all(19)
	gem_style.set_border_width_all(3)
	gem_style.border_color = Color(0.45, 0.3, 0.05)
	gem.add_theme_stylebox_override("panel", gem_style)
	_body.add_child(gem)
	var cost_label := _label(str(data.cost), 20, Color(0.2, 0.12, 0.02), HORIZONTAL_ALIGNMENT_CENTER)
	cost_label.size = gem.size
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem.add_child(cost_label)

	if data.ammo > 0:
		_build_ammo_badge()

	# Play-order badge over the art's top-right corner; shown while selected.
	_order_badge = Panel.new()
	_order_badge.position = Vector2(CARD_SIZE.x - 48, 44)
	_order_badge.size = Vector2(36, 36)
	_order_badge.pivot_offset = _order_badge.size / 2.0
	_order_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.12, 0.1, 0.08)
	badge_style.set_corner_radius_all(18)
	badge_style.set_border_width_all(3)
	badge_style.border_color = SELECTED_BORDER
	badge_style.shadow_color = Color(0, 0, 0, 0.6)
	badge_style.shadow_size = 4
	_order_badge.add_theme_stylebox_override("panel", badge_style)
	_body.add_child(_order_badge)
	_order_label = _label("", 20, SELECTED_BORDER, HORIZONTAL_ALIGNMENT_CENTER)
	_order_label.size = _order_badge.size
	_order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_order_label.add_theme_constant_override("outline_size", 3)
	_order_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_order_badge.add_child(_order_label)
	_order_badge.hide()

## Brass tag in the top-right corner: a bullet and the rounds the card fires.
## Also builds the hidden "EMPTY" tag shown over the art when it would click.
func _build_ammo_badge() -> void:
	var badge := Panel.new()
	badge.position = Vector2(CARD_SIZE.x - 40, -6)
	badge.size = Vector2(46, 30)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_style = StyleBoxFlat.new()
	_ammo_style.bg_color = Color(0.16, 0.12, 0.07)
	_ammo_style.set_corner_radius_all(8)
	_ammo_style.set_border_width_all(3)
	_ammo_style.border_color = BRASS
	badge.add_theme_stylebox_override("panel", _ammo_style)
	_body.add_child(badge)
	var bullet := BulletIcon.new()
	bullet.position = Vector2(7, 5)
	bullet.size = Vector2(10, 20)
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(bullet)
	var count := _label(str(data.ammo), 18, BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	count.position = Vector2(18, 0)
	count.size = Vector2(24, 30)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(count)

	_empty_tag = _label("EMPTY", 26, EMPTY_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_empty_tag.add_theme_constant_override("outline_size", 7)
	_empty_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	_empty_tag.position = Vector2(10, 64)
	_empty_tag.size = Vector2(CARD_SIZE.x - 20, 40)
	_empty_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_tag.rotation_degrees = -10
	_empty_tag.pivot_offset = _empty_tag.size / 2.0
	_empty_tag.hide()
	_body.add_child(_empty_tag)

## What this gun card would do if played now (a WeaponLibrary.Shot): fire
## (no tag), reload instead ("RELOAD") or click ("EMPTY"). No-op on other cards.
func set_shot(shot: int) -> void:
	if _empty_tag == null:
		return
	_empty_tag.visible = shot != WeaponLibrary.Shot.FIRES
	var color := BRASS if shot == WeaponLibrary.Shot.RELOADS else EMPTY_COLOR
	_empty_tag.text = "RELOAD" if shot == WeaponLibrary.Shot.RELOADS else "EMPTY"
	_empty_tag.add_theme_color_override("font_color", color)
	_ammo_style.border_color = BRASS if shot == WeaponLibrary.Shot.FIRES else color

## A brass cartridge, drawn in code.
class BulletIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, h * 0.4, w, h * 0.6), Color(0.9, 0.7, 0.32)) # case
		draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Color(0.6, 0.42, 0.15)) # rim
		var tip := PackedVector2Array()
		for i in 9: # Rounded lead tip.
			var a := PI + PI * i / 8.0
			tip.append(Vector2(w / 2.0 + cos(a) * w / 2.0, h * 0.4 + sin(a) * h * 0.4))
		draw_colored_polygon(tip, Color(0.72, 0.72, 0.76))

func _label(text: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _set_hovered(value: bool) -> void:
	_hovered = value
	_update_look()

func set_selected(value: bool) -> void:
	selected = value
	_update_look()

## Dims the card when it can't be afforded right now (selected cards stay lit).
func set_playable(value: bool) -> void:
	_playable = value
	_update_look()

## Keyboard cursor highlight.
func set_focused(value: bool) -> void:
	_focused = value
	_update_look()

## Shows this card's place in the play order (1 = plays first); 0 hides it.
func set_order(order: int) -> void:
	if _order_badge == null:
		return
	var was_visible := _order_badge.visible
	_order_badge.visible = order > 0
	_order_label.text = str(order)
	if order > 0 and not was_visible: # Pop in when the card is picked.
		_order_badge.scale = Vector2(0.4, 0.4)
		_order_badge.create_tween().tween_property(_order_badge, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Marks the card as resolving: it punches up, shakes and glows. Await the
## returned signal to wait for the wind-up before applying the card's effects.
func play_trigger() -> Signal:
	if _body == null:
		return get_tree().process_frame
	z_index = 1 # Draw over neighbours while enlarged.
	_frame_style.border_color = Color.WHITE
	_frame_style.shadow_color = Color(1.0, 0.85, 0.3, 0.8)
	_frame_style.shadow_size = 16
	_frame_style.shadow_offset = Vector2.ZERO
	if _trigger_tween:
		_trigger_tween.kill()
	_trigger_tween = create_tween()
	_trigger_tween.tween_property(_body, "scale", Vector2(1.12, 1.12), 0.08).set_ease(Tween.EASE_OUT)
	var shakes := [-7.0, 6.0, -5.0, 4.0, -2.0, 0.0]
	for i in shakes.size():
		var x: float = shakes[i]
		_trigger_tween.tween_property(_body, "position:x", x, 0.035)
		_trigger_tween.parallel().tween_property(_body, "rotation", deg_to_rad(x * 0.5), 0.035)
	_trigger_tween.tween_property(_body, "scale", Vector2(1.06, 1.06), 0.1)
	return _trigger_tween.finished

## The card has finished resolving: settle back and dim until discarded.
func finish_trigger() -> void:
	_spent = true
	z_index = 0
	if _body == null:
		return
	if _trigger_tween:
		_trigger_tween.kill()
	_trigger_tween = create_tween().set_parallel(true)
	_trigger_tween.tween_property(_body, "scale", Vector2.ONE, 0.12)
	_trigger_tween.tween_property(_body, "position:x", 0.0, 0.12)
	_trigger_tween.tween_property(_body, "rotation", 0.0, 0.12)
	_frame_style.shadow_color = Color(0, 0, 0, 0.5)
	_frame_style.shadow_size = 6
	_frame_style.shadow_offset = Vector2(0, 3)
	_update_look()

func _update_look() -> void:
	if _body == null:
		return
	if _spent:
		modulate = Color(0.5, 0.5, 0.55, 0.7)
		return
	var lift := 0.0
	if selected:
		lift = LIFT_ROOM
	elif _focused or (_hovered and _playable):
		lift = HOVER_LIFT
	_body.position.y = LIFT_ROOM - lift
	var border: Color = TYPE_COLORS.get(data.type, Color.GRAY)
	var width := 3
	if selected:
		border = SELECTED_BORDER
		width = 5
	if _focused:
		border = border.lerp(FOCUS_BORDER, 0.6) if selected else FOCUS_BORDER
		width += 2
	_frame_style.border_color = border
	_frame_style.set_border_width_all(width)
	modulate = Color.WHITE if (_playable or selected) else Color(0.55, 0.55, 0.6)
