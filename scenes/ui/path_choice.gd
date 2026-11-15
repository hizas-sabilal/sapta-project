extends Control
class_name PathChoice
## Shown at a room's exit: pick which room comes next.
## Set `options` (from RunManager.get_next_room_choices()) before adding to the tree.

signal chosen(room: Dictionary)

var options: Array[Dictionary] = []
var _done := false
var _buttons: Array[Button] = []
## Keyboard cursor over the room buttons. Hidden until the first key press,
## like the card screens, so a key still held from walking can't pick blind.
var _focus_index := 0
var _show_focus := false

const FOCUS_BORDER := Color(1, 0.85, 0.3)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var title := Label.new()
	title.text = "Room %d / %d  -  Where to next?" % [RunManager.room_index + 2, RunManager.ROOMS_PER_RUN]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)

	for room in options:
		var button := Button.new()
		button.text = "%s\n\n%s" % [RunManager.describe_room(room), RunManager.room_desc(room)]
		button.custom_minimum_size = Vector2(280, 160)
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE # Keys are handled below, not via ui_accept.
		button.pressed.connect(_choose.bind(room))
		row.add_child(button)
		_buttons.append(button)

	# Same keys as choosing cards.
	var hint := Label.new()
	hint.text = "%s  |  %s: choose      %s / %s: go      1-%d: pick room" % [
		Settings.describe("card_prev"), Settings.describe("card_next"),
		Settings.describe("card_select"), Settings.describe("card_execute"),
		_buttons.size()]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(hint)

## Keyboard: prev/next move the cursor, select or Action! go to the room under
## the cursor, Card 1-3 jump the cursor to that room (press again to go).
## The first press only shows the cursor.
func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or _buttons.is_empty():
		return
	# Ignore auto-repeat from a key still held while walking into the exit.
	if event.is_echo() and not _show_focus:
		return
	var slot := _slot_pressed(event)
	var handled := true
	if event.is_action_pressed("card_prev", true):
		_move_cursor(-1)
	elif event.is_action_pressed("card_next", true):
		_move_cursor(1)
	elif event.is_action_pressed("card_select") or event.is_action_pressed("card_execute"):
		if _show_focus:
			_choose(options[_focus_index])
		else:
			_move_cursor(0)
	elif slot >= 0 and slot < _buttons.size():
		if _show_focus and _focus_index == slot:
			_choose(options[slot])
		else:
			_focus_index = slot
			_show_focus = true
			_update_cursor()
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()

func _slot_pressed(event: InputEvent) -> int:
	for i in 3:
		if event.is_action_pressed("card_%d" % (i + 1)):
			return i
	return -1

func _move_cursor(step: int) -> void:
	if _show_focus:
		_focus_index = wrapi(_focus_index + step, 0, _buttons.size())
	_show_focus = true
	_update_cursor()

func _update_cursor() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		if _show_focus and i == _focus_index:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.25, 0.3)
			style.border_color = FOCUS_BORDER
			style.set_border_width_all(4)
			style.set_corner_radius_all(6)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")

func _choose(room: Dictionary) -> void:
	if _done:
		return
	_done = true
	hide()
	# Let the key press expire before the next room starts; otherwise Space
	# (select, also Jump) makes Iris jump the moment she spawns.
	for i in 2:
		await get_tree().physics_frame
	chosen.emit(room)
	queue_free()
