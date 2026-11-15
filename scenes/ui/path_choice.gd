extends Control
class_name PathChoice
## Shown at a room's exit: pick which room comes next.
## Set `options` (from RunManager.get_next_room_choices()) before adding to the tree.

signal chosen(room: Dictionary)

var options: Array[Dictionary] = []
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
		button.pressed.connect(_choose.bind(room))
		row.add_child(button)

func _choose(room: Dictionary) -> void:
	if _done:
		return
	_done = true
	chosen.emit(room)
	queue_free()
