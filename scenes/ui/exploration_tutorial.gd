extends CanvasLayer
## Controls hint shown in the first room of every run. Each line turns green once
## the player tries it; after move, jump and dash are all done it fades out.

const DONE_COLOR := Color(0.55, 1.0, 0.55)
const FADE_DELAY := 2.5
const FADE_TIME := 0.6

var _panel: PanelContainer
var _move_label: Label
var _jump_label: Label
var _dash_label: Label
var _moved := false
var _jumped := false
var _dashed := false
var _finishing := false

func _ready() -> void:
	# Default layer: menus in Main's OverlayContainer come later in the tree, so they draw on top.
	_panel = PanelContainer.new()
	_panel.position = Vector2(24, 24)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	margin.add_child(lines)

	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 22)
	lines.add_child(title)

	# Key names follow the player's bindings from Options.
	_move_label = _add_line(lines, "Move:  %s (left),  %s (right)" % [Settings.describe("Move left"), Settings.describe("Move right")])
	_jump_label = _add_line(lines, "Jump:  %s  (hold to jump higher)" % Settings.describe("Move up"))
	_dash_label = _add_line(lines, "Dash:  %s  (works in the air too)" % Settings.describe("Dash"))
	_add_line(lines, "Wall jump:  jump while sliding down a wall")
	_add_line(lines, "Pause:  Esc")
	_add_line(lines, "Touch a monster to start a battle")
	_add_line(lines, "Defeat every monster to unlock the exit")

func _add_line(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label

func _process(_delta: float) -> void:
	if not _moved and (Input.is_action_pressed("Move left") or Input.is_action_pressed("Move right")):
		_moved = true
		_mark_done(_move_label)
	if not _jumped and Input.is_action_just_pressed("Move up"):
		_jumped = true
		_mark_done(_jump_label)
	if not _dashed and Input.is_action_just_pressed("Dash"):
		_dashed = true
		_mark_done(_dash_label)
	if _moved and _jumped and _dashed and not _finishing:
		_finish()

func _mark_done(label: Label) -> void:
	label.text += "   - done!"
	label.modulate = DONE_COLOR

func _finish() -> void:
	_finishing = true
	await get_tree().create_timer(FADE_DELAY).timeout
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	queue_free()
