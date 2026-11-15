extends Control
class_name SkillTreeMenu
## Main-menu skill tree: spend coins (kept between runs) on permanent upgrades.
## Hover / focus a skill to read it, click (or Enter) to buy its next level.
## A skill unlocks once its parent has at least one level.
## Layout: the root skill on top, one column per branch below it.

signal closed

const NODE_SIZE := Vector2(220, 84)
const ROOT_POS := Vector2(640, 130) ## Centers.
const BRANCH_X := {"Body": 290.0, "Combat": 640.0, "Fortune": 990.0}
const FIRST_ROW_Y := 285.0
const ROW_GAP := 118.0

const BRANCH_COLORS := {
	"root": Color(0.75, 0.6, 1.0),
	"Body": Color(0.9, 0.38, 0.32),
	"Combat": Color(0.38, 0.62, 0.98),
	"Fortune": Color(1.0, 0.8, 0.3),
}
const GOLD := Color(1.0, 0.85, 0.3)
const LOCKED := Color(0.32, 0.32, 0.36)

var _buttons := {} ## skill id -> Button
var _centers := {} ## skill id -> Vector2
var _lines: Control
var _coins_label: Label
var _detail_title: Label
var _detail_text: Label
var _status: Label
var _selected := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_lines = Control.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)

	var title := _label("Skills", 36, Color.WHITE)
	title.position = Vector2(40, 24)
	add_child(title)

	_coins_label = _label("", 28, GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.position = Vector2(840, 28)
	_coins_label.size = Vector2(400, 40)
	add_child(_coins_label)

	_layout_skills()

	for branch in BRANCH_X:
		# Left-aligned so the connector line down the column's center misses it.
		var header := _label(branch.to_upper(), 18, BRANCH_COLORS[branch])
		header.size = Vector2(NODE_SIZE.x / 2.0 - 12, 24)
		header.position = Vector2(BRANCH_X[branch] - NODE_SIZE.x / 2.0 + 4, FIRST_ROW_Y - NODE_SIZE.y / 2.0 - 30)
		add_child(header)

	for s in Progress.SKILLS:
		var button := _make_node_button(s)
		_buttons[s.id] = button
		add_child(button)

	# Details of the hovered / focused skill.
	_detail_title = _label("", 22, Color.WHITE)
	_detail_title.position = Vector2(40, 604)
	add_child(_detail_title)
	_detail_text = _label("", 17, Color(0.82, 0.82, 0.88))
	_detail_text.position = Vector2(40, 636)
	_detail_text.size = Vector2(760, 24)
	add_child(_detail_text)
	_status = _label("", 16, Color(1, 0.6, 0.45))
	_status.position = Vector2(40, 666)
	_status.size = Vector2(760, 24)
	add_child(_status)

	var refund := _button("Refund all", Vector2(870, 640))
	refund.pressed.connect(_on_refund_pressed)
	var back := _button("Back", Vector2(1070, 640))
	back.pressed.connect(_close)

	Progress.coins_changed.connect(func(_c): _refresh())
	_refresh()
	_select("will")
	_buttons["will"].grab_focus()

func _layout_skills() -> void:
	var rows := {}
	for s in Progress.SKILLS:
		if s.branch == "root":
			_centers[s.id] = ROOT_POS
		else:
			var row: int = rows.get(s.branch, 0)
			rows[s.branch] = row + 1
			_centers[s.id] = Vector2(BRANCH_X[s.branch], FIRST_ROW_Y + row * ROW_GAP)

func _make_node_button(s: Dictionary) -> Button:
	var button := Button.new()
	button.position = _centers[s.id] - NODE_SIZE / 2.0
	button.size = NODE_SIZE
	button.custom_minimum_size = NODE_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(3)
		if state == "focus":
			style.draw_center = false
			style.border_color = Color.WHITE
			style.set_expand_margin_all(4)
		button.add_theme_stylebox_override(state, style)

	var name_label := _label(s.name, 19, Color.WHITE)
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 8)
	name_label.size = Vector2(NODE_SIZE.x, 26)
	button.add_child(name_label)

	var pips := Control.new() # Level pips, drawn.
	pips.name = "Pips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.position = Vector2(0, 38)
	pips.size = Vector2(NODE_SIZE.x, 12)
	pips.draw.connect(_draw_pips.bind(pips, s.id))
	button.add_child(pips)

	var cost_label := _label("", 15, GOLD)
	cost_label.name = "Cost"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.position = Vector2(0, 54)
	cost_label.size = Vector2(NODE_SIZE.x, 22)
	button.add_child(cost_label)

	button.pressed.connect(_on_skill_pressed.bind(s.id))
	button.mouse_entered.connect(_select.bind(s.id))
	button.focus_entered.connect(_select.bind(s.id))
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return label

func _button(text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(180, 48)
	button.size = Vector2(180, 48)
	add_child(button)
	return button

# ---------------------------------------------------------------- State

func _refresh() -> void:
	_coins_label.text = "Coins: %d" % Progress.coins
	for s in Progress.SKILLS:
		_style_node(s)
	_lines.queue_redraw()
	if _selected != "":
		_select(_selected)

func _style_node(s: Dictionary) -> void:
	var button: Button = _buttons[s.id]
	var color: Color = BRANCH_COLORS[s.branch]
	var lvl := Progress.level(s.id)
	var unlocked := Progress.is_unlocked(s.id)
	var maxed := Progress.is_maxed(s.id)

	var bg := Color(0.11, 0.1, 0.14)
	var border := LOCKED
	if not unlocked:
		bg = Color(0.08, 0.08, 0.1)
	elif maxed:
		bg = color.darkened(0.6)
		border = GOLD
	elif lvl > 0:
		bg = color.darkened(0.72)
		border = color
	elif Progress.can_buy(s.id):
		border = color.darkened(0.15)

	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state)
		style.bg_color = bg.lightened(0.08) if state == "hover" else bg
		style.border_color = border.lightened(0.2) if state == "hover" else border

	var name_label: Label = button.get_node("Name")
	name_label.modulate = Color(1, 1, 1, 0.45 if not unlocked else 1.0)
	var cost_label: Label = button.get_node("Cost")
	if maxed:
		cost_label.text = "MAXED"
		cost_label.add_theme_color_override("font_color", GOLD)
	elif not unlocked:
		cost_label.text = "Locked"
		cost_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	else:
		cost_label.text = "%d coins" % Progress.next_cost(s.id)
		var affordable := Progress.coins >= Progress.next_cost(s.id)
		cost_label.add_theme_color_override("font_color", GOLD if affordable else Color(0.85, 0.45, 0.4))
	button.get_node("Pips").queue_redraw()

func _select(id: String) -> void:
	_selected = id
	var s := Progress.skill(id)
	var lvl := Progress.level(id)
	_detail_title.text = "%s   (Lv %d / %d)" % [s.name, lvl, s.max]
	var text := Progress.describe(id)
	if not Progress.is_unlocked(id):
		text += "   Requires %s." % Progress.skill(s.requires).name
	_detail_text.text = text

func _on_skill_pressed(id: String) -> void:
	_select(id)
	var s := Progress.skill(id)
	if Progress.is_maxed(id):
		_status.text = "%s is already maxed." % s.name
	elif not Progress.is_unlocked(id):
		_status.text = "Buy %s first." % Progress.skill(s.requires).name
	elif not Progress.buy(id):
		_status.text = "Not enough coins (need %d)." % Progress.next_cost(id)
	else:
		_status.text = ""
		_pulse(_buttons[id])
	_refresh()

func _on_refund_pressed() -> void:
	var refunded := Progress.refund_all()
	_status.text = "Refunded %d coins." % refunded if refunded > 0 else "Nothing to refund."
	_refresh()

func _pulse(button: Button) -> void:
	button.pivot_offset = NODE_SIZE / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * 1.08, 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)

# ---------------------------------------------------------------- Drawing

## Lines from each skill to its parent; lit once the child is unlocked.
## The root's children share one stub down to a fork, drawn once in the
## root's color (branches drawing it themselves painted over each other).
## Dim lines go first so a lit line is never covered by a dim one.
func _draw_lines() -> void:
	var dim := Color(0.25, 0.25, 0.3)
	var segments := [] ## [points, color, lit]
	var fork_y := ROOT_POS.y + NODE_SIZE.y / 2.0 \
		+ (FIRST_ROW_Y - ROOT_POS.y - NODE_SIZE.y) / 2.0 - 10.0
	var root_lit := false
	for s in Progress.SKILLS:
		if s.requires == "":
			continue
		var from: Vector2 = _centers[s.requires]
		var to: Vector2 = _centers[s.id]
		var lit := Progress.is_unlocked(s.id)
		var color: Color = BRANCH_COLORS[s.branch] if lit else dim
		if Progress.skill(s.requires).branch == "root":
			root_lit = root_lit or lit
			segments.append([PackedVector2Array([Vector2(from.x, fork_y),
				Vector2(to.x, fork_y), to]), color, lit])
		else:
			segments.append([PackedVector2Array([from, to]), color, lit])
	segments.append([PackedVector2Array([ROOT_POS, Vector2(ROOT_POS.x, fork_y)]),
		BRANCH_COLORS["root"] if root_lit else dim, root_lit])

	for pass_lit in [false, true]:
		for seg in segments:
			if seg[2] == pass_lit:
				_lines.draw_polyline(seg[0], seg[1], 4.0 if pass_lit else 2.0, true)

func _draw_pips(pips: Control, id: String) -> void:
	var s := Progress.skill(id)
	var count: int = s.max
	var lvl := Progress.level(id)
	var pip := Vector2(14, 8)
	var gap := 5.0
	var total_w := count * pip.x + (count - 1) * gap
	var x0 := (NODE_SIZE.x - total_w) / 2.0
	var color: Color = BRANCH_COLORS[s.branch]
	for i in count:
		var rect := Rect2(Vector2(x0 + i * (pip.x + gap), 2), pip)
		pips.draw_rect(rect, color if i < lvl else Color(0.2, 0.2, 0.24))

# ---------------------------------------------------------------- Input

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
