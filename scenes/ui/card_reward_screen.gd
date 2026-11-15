extends Control
class_name CardRewardScreen
## "Pick 1 of N cards (or skip)". Adds the picked card to the run deck,
## emits finished(card or null), then frees itself.

signal finished(card: CardData)

const CARD_SCENE := preload("res://scenes/battles/card_ui.tscn")

var title_text := "Choose a card to add to your deck"
var _done := false
var _cards: Array = []
var _skip: Button
## Keyboard cursor: 0..cards-1 are the cards, cards.size() is the Skip button.
## Hidden until the first card key, like in battle.
var _focus_index := 0
var _show_focus := false
var _selected = null ## Card selected with Space / 1-3, confirmed with Enter.

const SKIP_BORDER := Color(1, 1, 1)

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
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for card_data in RunManager.get_reward_choices():
		var card_ui = CARD_SCENE.instantiate()
		card_ui.data = card_data
		card_ui.clicked.connect(_pick)
		row.add_child(card_ui)
		_cards.append(card_ui)
	box.add_child(row)

	_skip = Button.new()
	_skip.text = "Skip"
	_skip.focus_mode = Control.FOCUS_NONE # Keys are handled below, not via ui_accept.
	_skip.custom_minimum_size = Vector2(150, 45)
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip.pressed.connect(_pick.bind(null))
	box.add_child(_skip)

	# Same keys as choosing cards in battle.
	var hint := Label.new()
	hint.text = "%s  |  %s: choose      %s: select      %s: confirm" % [
		Settings.describe("card_prev"), Settings.describe("card_next"),
		Settings.describe("card_select"), Settings.describe("card_execute")]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(hint)

## Keyboard, same as a battle: prev/next move the cursor (past the last card
## is Skip), select / Card 1-3 select a card, Action! (Enter) confirms: the
## selected card, else the card under the cursor, or Skip when it's on Skip.
func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or _cards.is_empty():
		return
	var slot := _card_slot_pressed(event)
	var handled := true
	if event.is_action_pressed("card_prev", true):
		_move_cursor(-1)
	elif event.is_action_pressed("card_next", true):
		_move_cursor(1)
	elif event.is_action_pressed("card_select"):
		if not _show_focus:
			_move_cursor(0) # First press only shows the cursor.
		elif _focus_index == _cards.size():
			_confirm() # Select on Skip = skip.
		else:
			_toggle_select(_cards[_focus_index])
	elif event.is_action_pressed("card_execute"):
		_confirm()
	elif slot >= 0 and slot < _cards.size():
		_focus_index = slot
		_show_focus = true
		_toggle_select(_cards[slot])
	else:
		handled = false
	# Mark it handled before acting further: picking hands control back to
	# the game, which may take this screen out of the tree (no viewport).
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()

func _card_slot_pressed(event: InputEvent) -> int:
	for i in 3:
		if event.is_action_pressed("card_%d" % (i + 1)):
			return i
	return -1

func _move_cursor(step: int) -> void:
	if _show_focus:
		_focus_index = wrapi(_focus_index + step, 0, _cards.size() + 1)
	_show_focus = true
	if _focus_index == _cards.size() and _selected:
		# On Skip, Enter skips: drop the selection so the screen shows that.
		_selected.set_selected(false)
		_selected = null
	_update_cursor()

func _toggle_select(card) -> void:
	if _selected and _selected != card:
		_selected.set_selected(false)
	_selected = null if card.selected else card
	card.set_selected(_selected == card)
	_update_cursor()

func _confirm() -> void:
	if _selected:
		_pick(_selected)
	elif not _show_focus:
		_move_cursor(0) # Nothing chosen yet: show the cursor, don't pick blind.
	elif _focus_index < _cards.size():
		_pick(_cards[_focus_index])
	else:
		_pick(null)

func _update_cursor() -> void:
	for i in _cards.size():
		_cards[i].set_focused(_show_focus and i == _focus_index)
	var on_skip := _show_focus and _focus_index == _cards.size()
	if on_skip:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.25, 0.3)
		style.border_color = SKIP_BORDER
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		_skip.add_theme_stylebox_override("normal", style)
	else:
		_skip.remove_theme_stylebox_override("normal")

func _pick(card_ui) -> void:
	if _done:
		return # Ignore extra clicks.
	_done = true
	var data: CardData = card_ui.data if card_ui else null
	if data:
		RunManager.add_card(data)
	hide()
	# Let the key press expire before handing control back; otherwise Space
	# (select card, also Jump) makes Iris jump the moment exploration resumes.
	for i in 2:
		await get_tree().physics_frame
	finished.emit(data)
	queue_free()
