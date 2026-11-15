extends Control
class_name CardRewardScreen
## "Pick 1 of N cards (or skip)". Adds the picked card to the run deck,
## emits finished(card or null), then frees itself.

signal finished(card: CardData)

const CARD_SCENE := preload("res://scenes/battles/card_ui.tscn")

var title_text := "Choose a card to add to your deck"
var _done := false
var _cards: Array = []
var _focus_index := 0
var _show_focus := false

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

	var skip := Button.new()
	skip.text = "Skip  (%s)" % Settings.describe("card_execute")
	skip.focus_mode = Control.FOCUS_NONE # Keys are handled below, not via ui_accept.
	skip.custom_minimum_size = Vector2(150, 45)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_pick.bind(null))
	box.add_child(skip)

## Keyboard: prev/next move the cursor, select picks it, Card 1-3 pick
## directly, Action! skips.
func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or _cards.is_empty():
		return
	var step := 0
	var pick_slot := -1
	if event.is_action_pressed("card_prev", true):
		step = -1
	elif event.is_action_pressed("card_next", true):
		step = 1
	elif event.is_action_pressed("card_select"):
		pick_slot = _focus_index
	elif not event.is_action_pressed("card_execute"):
		for i in mini(_cards.size(), 3):
			if event.is_action_pressed("card_%d" % (i + 1)):
				pick_slot = i
				break
		if pick_slot < 0:
			return # Not one of our keys.

	# Mark it handled before acting: picking hands control back to the game,
	# which may take this screen out of the tree (no viewport afterwards).
	get_viewport().set_input_as_handled()

	if step != 0 or (pick_slot >= 0 and not _show_focus and event.is_action_pressed("card_select")):
		# Moving, or the first select press, only shows / moves the cursor,
		# so nothing is picked blind.
		if _show_focus:
			_focus_index = wrapi(_focus_index + step, 0, _cards.size())
		_show_focus = true
		for i in _cards.size():
			_cards[i].set_focused(i == _focus_index)
	elif pick_slot >= 0:
		_pick(_cards[pick_slot])
	else:
		_pick(null) # Action! key = Skip.

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
