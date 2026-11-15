extends Button
class_name ActionButton
## The battle's "Action!" button, drawn in code.
## Three looks:
##   ready  - cards are selected: warm red with a pulsing gold glow
##   pass   - nothing selected: cool slate "END TURN"
##   busy   - cards / enemy resolving: dark and dimmed (disabled)
## A small badge in the corner shows the keyboard key for it.

const BUTTON_SIZE := Vector2(230, 64)

const READY_BG := Color(0.80, 0.29, 0.16)
const READY_BORDER := Color(1.0, 0.85, 0.3)
const PASS_BG := Color(0.19, 0.23, 0.31)
const PASS_BORDER := Color(0.55, 0.63, 0.78)
const BUSY_BG := Color(0.14, 0.14, 0.16)
const BUSY_BORDER := Color(0.32, 0.32, 0.36)

const GLOW_MIN := 4.0
const GLOW_MAX := 14.0
const GLOW_SPEED := 4.0
const PRESS_SHIFT := 3.0

var _selected_count := 0
var _ap_used := 0
var _ap_max := 3

var _styles := {} ## state name ("normal", "hover", ...) -> StyleBoxFlat
var _content: Control
var _title: Label
var _subtitle: Label
var _badge: PanelContainer
var _badge_label: Label
var _time := 0.0

func _ready() -> void:
	text = "" # Our own labels draw the text.
	custom_minimum_size = BUTTON_SIZE
	size = BUTTON_SIZE
	pivot_offset = BUTTON_SIZE / 2.0
	focus_mode = Control.FOCUS_NONE # Space/Enter are handled by the battle, not ui_accept.
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(14)
		style.set_border_width_all(3)
		style.shadow_offset = Vector2(0, 3)
		_styles[state] = style
		add_theme_stylebox_override(state, style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_title = _label(26, 6)
	_title.position = Vector2(0, 6)
	_title.size = Vector2(BUTTON_SIZE.x, 32)
	_content.add_child(_title)

	_subtitle = _label(14, 4)
	_subtitle.position = Vector2(0, 37)
	_subtitle.size = Vector2(BUTTON_SIZE.x, 18)
	_content.add_child(_subtitle)

	_build_badge()
	Settings.bindings_changed.connect(_update_badge)
	_update_badge()
	_apply_look()

func _label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label

## Key-cap badge hanging off the top-right corner.
func _build_badge() -> void:
	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.border_color = Color(0.85, 0.85, 0.9)
	style.set_border_width_all(2)
	style.border_width_bottom = 4 # Reads as a key cap.
	style.set_corner_radius_all(6)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	_badge.add_theme_stylebox_override("panel", style)
	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.add_theme_font_size_override("font_size", 12)
	_badge.add_child(_badge_label)
	add_child(_badge)

func _update_badge() -> void:
	var keys := Settings.get_keys("card_execute")
	_badge_label.text = Settings.key_name(keys[0]) if not keys.is_empty() else ""
	_badge.visible = _badge_label.text != ""
	_badge.reset_size()
	_badge.position = Vector2(BUTTON_SIZE.x - _badge.get_combined_minimum_size().x + 8, -12)

## Called by the battle whenever the selection, AP or busy state changes
## (set `disabled` first).
func set_state(selected_count: int, ap_used: int, ap_max: int) -> void:
	_selected_count = selected_count
	_ap_used = ap_used
	_ap_max = ap_max
	_apply_look()

func _apply_look() -> void:
	if _title == null:
		return
	var bg := PASS_BG
	var border := PASS_BORDER
	if disabled:
		bg = BUSY_BG
		border = BUSY_BORDER
		_title.text = "ACTION!" if _selected_count > 0 else "WAIT..."
		_subtitle.text = "Resolving..."
	elif _selected_count > 0:
		bg = READY_BG
		border = READY_BORDER
		_title.text = "ACTION!"
		_subtitle.text = "%d card%s  -  %d/%d AP" % [_selected_count,
			"" if _selected_count == 1 else "s", _ap_used, _ap_max]
	else:
		_title.text = "END TURN"
		_subtitle.text = "No cards selected"

	var bgs := {
		"normal": bg,
		"hover": bg.lightened(0.15),
		"pressed": bg.darkened(0.2),
		"disabled": bg,
	}
	for state in _styles:
		var style: StyleBoxFlat = _styles[state]
		style.bg_color = bgs[state]
		style.border_color = border.lightened(0.2) if state == "hover" else border
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 6
	_styles["pressed"].shadow_size = 2
	_styles["pressed"].shadow_offset = Vector2(0, 1)

	var alpha := 0.45 if disabled else 1.0
	_title.modulate.a = alpha
	_subtitle.modulate.a = alpha
	_title.add_theme_color_override("font_color", Color(1, 0.96, 0.85) if _selected_count > 0 else Color.WHITE)
	_subtitle.add_theme_color_override("font_color", Color(1, 0.9, 0.65) if _selected_count > 0 and not disabled else Color(0.8, 0.84, 0.9))
	_badge.modulate.a = 0.0 if disabled else 1.0
	if disabled or _selected_count == 0:
		scale = Vector2.ONE

func _process(delta: float) -> void:
	_time += delta
	var pressed_now := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	_content.position.y = PRESS_SHIFT if pressed_now else 0.0

	if disabled or _selected_count == 0:
		return
	# Ready to fire: gold glow breathes and the button swells a touch.
	var wave := (sin(_time * GLOW_SPEED) + 1.0) / 2.0
	for state in ["normal", "hover"]:
		var style: StyleBoxFlat = _styles[state]
		style.shadow_color = Color(READY_BORDER, 0.35 + 0.3 * wave)
		style.shadow_size = int(lerpf(GLOW_MIN, GLOW_MAX, wave))
	if not pressed_now:
		scale = Vector2.ONE * (1.0 + 0.025 * wave)
