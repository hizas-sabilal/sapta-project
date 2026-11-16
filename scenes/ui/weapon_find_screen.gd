extends Control
class_name WeaponFindScreen
## "Found a <weapon>!": shows its cards and ammo, and what equipping it costs
## (the current weapon and its ammo stay behind). Emits finished(true) if the
## player takes it, then frees itself. Taking it is up to the caller.
##
## Keyboard: left / right pick Take or Leave, Enter / Space confirms, Esc leaves.

signal finished(taken: bool)

const CARD_SCENE := preload("res://scenes/battles/card_ui.tscn")
const GOLD := Color(1.0, 0.85, 0.3)

var weapon: WeaponData
var _take: Button
var _leave: Button
var _done := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var new_tag := "" if Progress.is_weapon_unlocked(weapon) else "   NEW!"
	box.add_child(_label("Found a %s!%s" % [weapon.weapon_name, new_tag], 34, GOLD))
	box.add_child(_label(weapon.description, 17, Color(0.85, 0.85, 0.9)))
	box.add_child(_label(weapon.stats_text(), 16, Color(0.95, 0.78, 0.45)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(_label("Comes with:", 16, Color(0.85, 0.85, 0.9)))
	for card in weapon.kit:
		var card_ui = CARD_SCENE.instantiate()
		card_ui.data = card
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card_ui)
	box.add_child(row)

	var current := RunManager.weapon
	var losses: PackedStringArray = []
	var lost_cards := RunManager.weapon_card_count()
	if lost_cards > 0:
		losses.append("your %d %s card%s" % [lost_cards, current.weapon_name, "" if lost_cards == 1 else "s"])
	if current.uses_ammo():
		losses.append("its %d rounds" % (RunManager.magazine + RunManager.reserve_ammo))
	var swap_text := "Taking it leaves your %s behind" % current.weapon_name
	if not losses.is_empty():
		swap_text += ", with " + " and ".join(losses)
	box.add_child(_label(swap_text + ". General cards stay.", 16, Color(1, 0.6, 0.45)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	_take = _button("Take %s" % weapon.weapon_name, true)
	_leave = _button("Leave it", false)
	buttons.add_child(_take)
	buttons.add_child(_leave)
	box.add_child(buttons)
	_take.focus_neighbor_right = _leave.get_path()
	_leave.focus_neighbor_left = _take.get_path()
	_leave.grab_focus() # Safer default: a stray Enter doesn't throw your gun away.

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label

func _button(text: String, taken: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(_finish.bind(taken))
	return button

func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or not event.pressed:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_finish(false)
	elif event.is_action_pressed("card_prev") or event.is_action_pressed("ui_left"):
		_take.grab_focus()
	elif event.is_action_pressed("card_next") or event.is_action_pressed("ui_right"):
		_leave.grab_focus()
	elif event.is_action_pressed("card_select") or event.is_action_pressed("card_execute"):
		_finish(_take.has_focus())
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _finish(taken: bool) -> void:
	if _done:
		return
	_done = true
	hide()
	# Let the key press expire before handing control back (Space is also Jump).
	for i in 2:
		await get_tree().physics_frame
	finished.emit(taken)
	queue_free()
