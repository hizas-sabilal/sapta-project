extends CanvasLayer
## Run info in the top-right corner during exploration.

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -320
	_label.offset_right = -24
	_label.offset_top = 20
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)

func _process(_delta: float) -> void:
	_label.text = "Room %d / %d  -  %s\nHP %d / %d\nDeck: %d cards\nCoins: %d" % [
		RunManager.room_index + 1, RunManager.ROOMS_PER_RUN,
		RunManager.describe_room(RunManager.current_room),
		RunManager.hp, RunManager.max_hp, RunManager.deck.size(), Progress.coins]
