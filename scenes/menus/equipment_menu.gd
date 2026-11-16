extends Control
class_name EquipmentMenu
## Main-menu equipment screen: choose the weapon every run starts with.
## Left: every weapon (locked ones show their coin price) and Back.
## Right: the weapon under the cursor: its stats and the cards it adds to the deck.
## Click / Enter equips an unlocked weapon or buys a locked one.
##
## Keyboard: up / down (or W / S) move, Enter / Space choose, Esc back.

signal closed

const CARD_SCENE := preload("res://scenes/battles/card_ui.tscn")
const CardUI := preload("res://scenes/battles/card_ui.gd")
const CARD_SCALE := 0.9
const GOLD := Color(1.0, 0.85, 0.3)
const ERROR := Color(1, 0.6, 0.45)
const INFO := Color(0.55, 0.85, 1.0)
const LIST_X := 40.0
const LIST_W := 300.0
const DETAIL_X := 380.0

var _buttons: Array[Button] = [] ## one per WeaponLibrary.ALL entry, then Back
var _index := 0
var _coins_label: Label
var _name_label: Label
var _state_label: Label
var _desc_label: Label
var _stats_label: Label
var _cards_row: HBoxContainer
var _deck_label: Label
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label("Equipment", 36, Color.WHITE)
	title.position = Vector2(40, 24)
	add_child(title)
	var subtitle := _label("Choose the weapon every run starts with. Your deck holds general cards plus that weapon's cards.", 15, Color(0.75, 0.75, 0.82))
	subtitle.position = Vector2(40, 72)
	add_child(subtitle)

	_coins_label = _label("", 28, GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.position = Vector2(840, 28)
	_coins_label.size = Vector2(400, 40)
	add_child(_coins_label)

	for i in WeaponLibrary.ALL.size():
		_add_button(Vector2(LIST_X, 120 + i * 62))
	var back := _add_button(Vector2(LIST_X, 120 + WeaponLibrary.ALL.size() * 62 + 24))
	back.text = "Back"

	_name_label = _label("", 30, Color.WHITE)
	_name_label.position = Vector2(DETAIL_X, 116)
	add_child(_name_label)
	_state_label = _label("", 17, INFO)
	_state_label.position = Vector2(DETAIL_X, 156)
	add_child(_state_label)
	_desc_label = _label("", 16, Color(0.85, 0.85, 0.9))
	_desc_label.position = Vector2(DETAIL_X, 186)
	_desc_label.size = Vector2(860, 24)
	add_child(_desc_label)
	_stats_label = _label("", 16, Color(0.95, 0.78, 0.45))
	_stats_label.position = Vector2(DETAIL_X, 214)
	add_child(_stats_label)

	_deck_label = _label("", 15, Color(0.8, 0.8, 0.88))
	_deck_label.position = Vector2(DETAIL_X, 520)
	_deck_label.size = Vector2(860, 50)
	_deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_deck_label)

	_cards_row = HBoxContainer.new()
	_cards_row.position = Vector2(DETAIL_X, 250)
	_cards_row.add_theme_constant_override("separation", 14)
	add_child(_cards_row)

	_status = _label("", 16, ERROR)
	_status.position = Vector2(40, 660)
	_status.size = Vector2(1200, 24)
	add_child(_status)
	var hint := _label("Up / Down: move      Enter / Space: equip or buy      Esc: back", 14, Color(0.6, 0.6, 0.68))
	hint.position = Vector2(40, 690)
	add_child(hint)

	Progress.coins_changed.connect(func(_c): _refresh())
	get_viewport().gui_release_focus() # Keys are handled below, not by focus.
	_move_cursor(WeaponLibrary.ALL.find(Progress.starting_weapon()))

func _add_button(at: Vector2) -> Button:
	var button := Button.new()
	button.position = at
	button.size = Vector2(LIST_W, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	var index := _buttons.size()
	button.mouse_entered.connect(_move_cursor.bind(index))
	button.pressed.connect(func(): _move_cursor(index); _activate())
	add_child(button)
	_buttons.append(button)
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

# ---------------------------------------------------------------- State

func _refresh() -> void:
	_coins_label.text = "Coins: %d" % Progress.coins
	var equipped := Progress.starting_weapon()
	for i in WeaponLibrary.ALL.size():
		var weapon: WeaponData = WeaponLibrary.ALL[i]
		var tag := ""
		if weapon == equipped:
			tag = "   [equipped]"
		elif not Progress.is_weapon_unlocked(weapon):
			tag = "   (%d coins)" % weapon.unlock_cost
		_buttons[i].text = "  %s%s" % [weapon.weapon_name, tag]
		_buttons[i].modulate = Color.WHITE if Progress.is_weapon_unlocked(weapon) else Color(1, 1, 1, 0.6)
	_update_cursor()
	_show_detail()

func _selected_weapon() -> WeaponData:
	return WeaponLibrary.ALL[_index] if _index < WeaponLibrary.ALL.size() else null

func _show_detail() -> void:
	var weapon := _selected_weapon()
	if weapon == null:
		return # On Back: keep showing the last weapon.
	_name_label.text = weapon.weapon_name
	if weapon == Progress.starting_weapon():
		_state_label.text = "Equipped: every run starts with it."
		_state_label.add_theme_color_override("font_color", INFO)
	elif Progress.is_weapon_unlocked(weapon):
		_state_label.text = "Unlocked. Enter / click to equip."
		_state_label.add_theme_color_override("font_color", INFO)
	else:
		_state_label.text = "Locked: unlock for %d coins, or find it in a chest." % weapon.unlock_cost
		_state_label.add_theme_color_override("font_color",
			GOLD if Progress.coins >= weapon.unlock_cost else ERROR)
	_desc_label.text = weapon.description
	_stats_label.text = weapon.stats_text()

	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	var card_size: Vector2 = (CardUI.CARD_SIZE + Vector2(0, CardUI.LIFT_ROOM)) * CARD_SCALE
	var unlocked := weapon.pool.filter(func(c): return Progress.is_card_unlocked(c)).size()
	_deck_label.text = "Starting deck: %s\n%s cards: %d of %d unlocked (build its deck in Deck). Shown: what it comes with when found in a chest." % [
		WeaponData.names_text(Progress.starting_deck(weapon)), weapon.weapon_name, unlocked, weapon.pool.size()]
	for card in weapon.kit:
		var slot := Control.new() # Scaled cards don't shrink their layout size; the slot does.
		slot.custom_minimum_size = card_size
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_ui = CARD_SCENE.instantiate()
		card_ui.data = card
		card_ui.scale = Vector2.ONE * CARD_SCALE
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(card_ui)
		_cards_row.add_child(slot)

## Enter / Space / click on the entry under the cursor.
func _activate() -> void:
	var weapon := _selected_weapon()
	if weapon == null:
		_close()
		return
	if not Progress.is_weapon_unlocked(weapon):
		if Progress.buy_weapon(weapon):
			Progress.set_starting_weapon(weapon)
			_say("Unlocked and equipped the %s!" % weapon.weapon_name, GOLD)
		else:
			_say("Not enough coins (need %d)." % weapon.unlock_cost)
	elif weapon != Progress.starting_weapon():
		Progress.set_starting_weapon(weapon)
		_say("Runs now start with the %s." % weapon.weapon_name, INFO)
	_refresh()

func _say(text: String, color := ERROR) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)

# ---------------------------------------------------------------- Cursor

func _move_cursor(index: int) -> void:
	_index = clampi(index, 0, _buttons.size() - 1)
	_refresh()

func _update_cursor() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		if i == _index:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.25, 0.3)
			style.border_color = GOLD
			style.set_border_width_all(3)
			style.set_corner_radius_all(6)
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var handled := true
	if event.physical_keycode == KEY_ESCAPE and not event.echo:
		_close()
	elif event.is_action_pressed("ui_up", true) or event.physical_keycode == KEY_W:
		_move_cursor(wrapi(_index - 1, 0, _buttons.size()))
	elif event.is_action_pressed("ui_down", true) or event.physical_keycode == KEY_S:
		_move_cursor(wrapi(_index + 1, 0, _buttons.size()))
	elif not event.echo and (event.is_action_pressed("ui_accept") or event.is_action_pressed("card_select") \
			or event.is_action_pressed("card_execute")):
		_activate()
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
