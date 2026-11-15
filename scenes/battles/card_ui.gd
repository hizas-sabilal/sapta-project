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
}
const SELECTED_BORDER := Color(1.0, 0.85, 0.3)
const FOCUS_BORDER := Color(1.0, 1.0, 1.0)

@export var data: CardData

var selected := false
var _hovered := false
var _focused := false ## Keyboard cursor is on this card.
var _playable := true

var _body: Panel
var _frame_style: StyleBoxFlat

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
	var name_size := 17 if data.card_name.length() <= 12 else 14 # Long names still fit.
	var name_label := _label(data.card_name, name_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(36, 8)
	name_label.size = Vector2(CARD_SIZE.x - 44, 26)
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
	ribbon_style.set_corner_radius_all(4)
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	_body.add_child(ribbon)
	var type_label := _label(data.type_name().to_upper(), 11, color.lightened(0.6), HORIZONTAL_ALIGNMENT_CENTER)
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

func _update_look() -> void:
	if _body == null:
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
