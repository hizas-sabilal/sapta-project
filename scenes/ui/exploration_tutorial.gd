extends CanvasLayer
## Controls hint shown in exploration until the player has moved and jumped once.
## Completion is saved, so it only appears on a first playthrough.
## To see it again, delete user://progress.cfg
## (Project > Open User Data Folder in the editor).

const SAVE_PATH := "user://progress.cfg"
const DONE_COLOR := Color(0.55, 1.0, 0.55)
const FADE_DELAY := 2.5
const FADE_TIME := 0.6

var _panel: PanelContainer
var _move_label: Label
var _jump_label: Label
var _moved := false
var _jumped := false
var _finishing := false

static func should_show() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return true
	return not cfg.get_value("tutorial", "exploration_done", false)

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

	_move_label = _add_line(lines, "Move:  A / D  or  Left / Right")
	_jump_label = _add_line(lines, "Jump:  W / Space / Up  (hold to jump higher)")
	_add_line(lines, "Pause:  Esc")
	_add_line(lines, "Touch a monster to start a battle")

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
	if _moved and _jumped and not _finishing:
		_finish()

func _mark_done(label: Label) -> void:
	label.text += "   - done!"
	label.modulate = DONE_COLOR

func _finish() -> void:
	_finishing = true
	_save_done()
	await get_tree().create_timer(FADE_DELAY).timeout
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	queue_free()

func _save_done() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH) # Keep any other saved values; fine if the file doesn't exist yet.
	cfg.set_value("tutorial", "exploration_done", true)
	cfg.save(SAVE_PATH)
