extends Control
class_name OptionsMenu
## Options screen. For now only key bindings (no music / sfx yet).
## Click a key button, then press the new key. Esc cancels, right-click clears
## an alternate key. Changes save immediately through the Settings autoload.

signal closed

var _rows := {} ## action -> Array[Button] (one per key slot)
var _waiting_action := ""
var _waiting_slot := -1
var _status: Label
var _back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks to the menu underneath.

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var group := ""
	for entry in Settings.REBINDABLE:
		if entry.group != group:
			group = entry.group
			list.add_child(_header(group))
		list.add_child(_binding_row(entry))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(_status)
	_show_default_status()

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.custom_minimum_size = Vector2(200, 45)
	reset.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(200, 45)
	_back_button.pressed.connect(_close)
	buttons.add_child(_back_button)

	_refresh()
	_back_button.grab_focus()

func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	return label

func _binding_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = entry.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)

	var slots: Array[Button] = []
	for slot in Settings.MAX_KEYS_PER_ACTION:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 36)
		button.pressed.connect(_start_rebind.bind(entry.action, slot))
		button.gui_input.connect(_on_slot_gui_input.bind(entry.action, slot))
		row.add_child(button)
		slots.append(button)
	_rows[entry.action] = slots
	return row

func _refresh() -> void:
	for action in _rows:
		var keys := Settings.get_keys(action)
		var slots: Array = _rows[action]
		for slot in slots.size():
			var button: Button = slots[slot]
			if action == _waiting_action and slot == _waiting_slot:
				button.text = "Press a key..."
			elif slot < keys.size():
				button.text = Settings.key_name(keys[slot])
			else:
				button.text = "-"

func _start_rebind(action: String, slot: int) -> void:
	_waiting_action = action
	_waiting_slot = slot
	_status.text = "Press a key for \"%s\"  (Esc to cancel)" % _label_of(action)
	_refresh()

func _on_slot_gui_input(event: InputEvent, action: String, slot: int) -> void:
	# Right-click clears that key (an action always keeps at least one).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_rebind()
		if not Settings.clear_key(action, slot):
			_status.text = "\"%s\" needs at least one key" % _label_of(action)
		_refresh()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode

	if _waiting_action == "":
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()
		return

	get_viewport().set_input_as_handled() # Don't let the key also press a button.
	if key == KEY_ESCAPE:
		_cancel_rebind()
		return
	if Settings.is_reserved(key):
		_status.text = "%s is reserved, pick another key" % Settings.key_name(key)
		return

	var action := _waiting_action
	var stolen_from := Settings.set_key(action, _waiting_slot, key)
	_waiting_action = ""
	_waiting_slot = -1
	if stolen_from != "":
		_status.text = "%s moved from \"%s\" to \"%s\"" % [Settings.key_name(key), stolen_from, _label_of(action)]
	else:
		_show_default_status()
	_refresh()

func _cancel_rebind() -> void:
	_waiting_action = ""
	_waiting_slot = -1
	_show_default_status()
	_refresh()

func _on_reset_pressed() -> void:
	_cancel_rebind()
	Settings.reset_to_defaults()
	_status.text = "Controls reset to defaults"
	_refresh()

func _show_default_status() -> void:
	_status.text = "Click a key to change it  -  right-click to clear  -  Esc to go back"

func _label_of(action: String) -> String:
	for entry in Settings.REBINDABLE:
		if entry.action == action:
			return entry.label
	return action

func _close() -> void:
	closed.emit()
	queue_free()
