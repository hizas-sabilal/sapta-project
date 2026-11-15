extends Control
class_name CardRewardScreen
## "Pick 1 of N cards (or skip)". Adds the picked card to the run deck,
## emits finished(card or null), then frees itself.

signal finished(card: CardData)

const CARD_SCENE := preload("res://scenes/battles/card_ui.tscn")

var title_text := "Choose a card to add to your deck"
var _done := false

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
	box.add_child(row)

	var skip := Button.new()
	skip.text = "Skip"
	skip.custom_minimum_size = Vector2(150, 45)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_pick.bind(null))
	box.add_child(skip)

func _pick(card_ui) -> void:
	if _done:
		return # Ignore extra clicks.
	_done = true
	var data: CardData = card_ui.data if card_ui else null
	if data:
		RunManager.add_card(data)
	finished.emit(data)
	queue_free()
