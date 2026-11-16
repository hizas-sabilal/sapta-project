extends Control
class_name DeckMenu
## Main-menu deck builder for the starting weapon (chosen in Equipment).
## Left: the general cards and that weapon's cards (locked ones show their
## coin price). Right: the starting deck runs with that weapon begin with.
## Every weapon keeps its own starting deck.
## Click / Enter a card to add it (or buy it if locked); click / Enter a deck
## slot to take that card out. A complete deck is saved right away.
##
## Keyboard: arrows (or A/D/W/S) move a cursor over the collection; moving
## right past its last column goes to the deck list (slots, Reset, Back).

signal closed

const CARD_SCENE := preload("res://scenes/battles/card_ui.tscn")
const CardUI := preload("res://scenes/battles/card_ui.gd")
const CARD_SCALE := 0.75
const COLUMNS := 6
const GOLD := Color(1.0, 0.85, 0.3)
const ERROR := Color(1, 0.6, 0.45)
const SIDE_X := 960.0
const SIDE_W := 290.0
const SLOT_STEP := 46 ## Vertical spacing of the deck slots.

enum Zone { GRID, SIDE }

var _weapon: WeaponData
var _collection: Array[CardData] = [] ## general cards + the weapon's pool
var _deck: Array[CardData] = []
var _cards: Array = [] ## card_ui per _collection entry
var _slots: Array[Control] = [] ## wrapper of each card_ui (what the grid lays out)
var _overlays: Array[Label] = [] ## "LOCKED / price" or "In deck x2" under each card
var _side_buttons: Array[Button] = [] ## deck slots, then Reset, then Back
var _scroll: ScrollContainer
var _coins_label: Label
var _deck_title: Label
var _problem: Label
var _detail_title: Label
var _detail_text: Label
var _status: Label

var _zone := Zone.GRID
var _grid_index := 0
var _side_index := 0
var _leave_warned := false ## Back was pressed once with an incomplete deck.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon = Progress.starting_weapon()
	_collection = CardLibrary.cards_for(_weapon)
	_deck = Progress.starting_deck(_weapon)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label("Deck  -  %s" % _weapon.weapon_name, 36, Color.WHITE)
	title.position = Vector2(40, 24)
	add_child(title)
	var subtitle := _label("General cards + %s cards (change weapon in Equipment). Unlock cards with coins, or find them in runs." % _weapon.weapon_name, 15, Color(0.75, 0.75, 0.82))
	subtitle.position = Vector2(40, 72)
	add_child(subtitle)

	_coins_label = _label("", 28, GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.position = Vector2(840, 28)
	_coins_label.size = Vector2(400, 40)
	add_child(_coins_label)

	_build_collection()
	_build_side()

	_detail_title = _label("", 21, Color.WHITE)
	_detail_title.position = Vector2(40, 600)
	add_child(_detail_title)
	_detail_text = _label("", 16, Color(0.82, 0.82, 0.88))
	_detail_text.position = Vector2(40, 630)
	_detail_text.size = Vector2(880, 24)
	add_child(_detail_text)
	_status = _label("", 16, ERROR)
	_status.position = Vector2(40, 660)
	_status.size = Vector2(880, 24)
	add_child(_status)

	var hint := _label("Arrows / A D: move      Enter / Space: add, buy or remove      Esc: back", 14, Color(0.6, 0.6, 0.68))
	hint.position = Vector2(40, 690)
	add_child(hint)

	Progress.coins_changed.connect(func(_c): _refresh())
	get_viewport().gui_release_focus() # Keys are handled below, not by focus.
	_refresh()
	_move_cursor_to(Zone.GRID, 0)

func _build_collection() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(30, 104)
	_scroll.size = Vector2(900, 486)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	_scroll.add_child(grid)

	var card_size: Vector2 = (CardUI.CARD_SIZE + Vector2(0, CardUI.LIFT_ROOM)) * CARD_SCALE
	for i in _collection.size():
		var data: CardData = _collection[i]
		var slot := Control.new()
		slot.custom_minimum_size = card_size + Vector2(0, 22)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(slot)

		var card_ui = CARD_SCENE.instantiate()
		card_ui.data = data
		card_ui.scale = Vector2.ONE * CARD_SCALE
		card_ui.clicked.connect(func(_c): _move_cursor_to(Zone.GRID, i); _activate())
		card_ui.mouse_entered.connect(func(): _move_cursor_to(Zone.GRID, i, false))
		slot.add_child(card_ui)
		card_ui.mouse_filter = Control.MOUSE_FILTER_PASS # Let the wheel reach the scroll container.

		var overlay := _label("", 14, GOLD)
		overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.position = Vector2(0, card_size.y)
		overlay.size = Vector2(card_size.x, 20)
		slot.add_child(overlay)

		_cards.append(card_ui)
		_slots.append(slot)
		_overlays.append(overlay)

func _build_side() -> void:
	_deck_title = _label("", 22, Color.WHITE)
	_deck_title.position = Vector2(SIDE_X, 104)
	add_child(_deck_title)

	for i in CardLibrary.DECK_SIZE:
		var button := _side_button(Vector2(SIDE_X, 140 + i * SLOT_STEP))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): _move_cursor_to(Zone.SIDE, i); _activate())

	var below := 140 + CardLibrary.DECK_SIZE * SLOT_STEP
	_problem = _label("", 14, ERROR)
	_problem.position = Vector2(SIDE_X, below)
	_problem.size = Vector2(SIDE_W, 44)
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_problem)

	var reset := _side_button(Vector2(SIDE_X, below + 48))
	reset.text = "Reset to default"
	var reset_index := _side_buttons.size() - 1
	reset.pressed.connect(func(): _move_cursor_to(Zone.SIDE, reset_index); _activate())
	var back := _side_button(Vector2(SIDE_X, below + 98))
	back.text = "Back"
	var back_index := _side_buttons.size() - 1
	back.pressed.connect(func(): _move_cursor_to(Zone.SIDE, back_index); _activate())

func _side_button(at: Vector2) -> Button:
	var button := Button.new()
	button.position = at
	button.size = Vector2(SIDE_W, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	var index := _side_buttons.size()
	button.mouse_entered.connect(func(): _move_cursor_to(Zone.SIDE, index, false))
	add_child(button)
	_side_buttons.append(button)
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

	for i in _collection.size():
		var data: CardData = _collection[i]
		var overlay := _overlays[i]
		var copies := CardLibrary.count_in(_deck, data)
		if not Progress.is_card_unlocked(data):
			overlay.text = "LOCKED  -  %d coins" % data.unlock_cost
			var affordable := Progress.coins >= data.unlock_cost
			overlay.add_theme_color_override("font_color", GOLD if affordable else Color(0.85, 0.45, 0.4))
			_cards[i].set_playable(false) # Dimmed.
		else:
			overlay.text = "In deck  x%d" % copies if copies > 0 else ""
			overlay.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
			_cards[i].set_playable(true)

	_deck_title.text = "Starting deck  (%d / %d)" % [_deck.size(), CardLibrary.DECK_SIZE]
	for i in CardLibrary.DECK_SIZE:
		var button := _side_buttons[i]
		if i < _deck.size():
			var card := _deck[i]
			button.text = "  [%d]  %s%s" % [card.cost, card.card_name, "   (rare)" if card.is_rare() else ""]
			button.modulate = Color.WHITE
		else:
			button.text = "  - empty -"
			button.modulate = Color(1, 1, 1, 0.55)
	_problem.text = CardLibrary.deck_problem(_deck, _weapon)
	_update_cursor()
	_show_detail()

func _show_detail() -> void:
	var card: CardData = null
	if _zone == Zone.GRID:
		card = _collection[_grid_index]
	elif _side_index < _deck.size():
		card = _deck[_side_index]
	if card == null:
		_detail_title.text = ""
		_detail_text.text = ""
		if _zone == Zone.SIDE and _side_index == CardLibrary.DECK_SIZE:
			_detail_text.text = "Go back to the default deck: %s." % ", ".join(
				CardLibrary.default_deck(_weapon).map(func(c): return c.card_name))
		return
	_detail_title.text = "%s   (%s%s, %d AP)" % [card.card_name, "Rare " if card.is_rare() else "",
		card.type_name(), card.cost]
	var text := card.rules_text().replace("\n", " ")
	if not Progress.is_card_unlocked(card):
		text += "   Locked: unlock for %d coins, or find it in a run." % card.unlock_cost
	elif _zone == Zone.GRID:
		text += "   In deck: %d / %d." % [CardLibrary.count_in(_deck, card), CardLibrary.max_copies(card)]
	else:
		text += "   Enter / click to take it out."
	_detail_text.text = text

## Enter / Space / click on the item under the cursor.
func _activate() -> void:
	_status.add_theme_color_override("font_color", ERROR)
	if _zone == Zone.GRID:
		var card: CardData = _collection[_grid_index]
		if not Progress.is_card_unlocked(card):
			if Progress.buy_card(card):
				_say("Unlocked %s!" % card.card_name, GOLD)
				_pulse(_slots[_grid_index])
			else:
				_say("Not enough coins (need %d)." % card.unlock_cost)
		else:
			var problem := CardLibrary.add_problem(_deck, card)
			if problem != "":
				_say(problem)
			else:
				_deck.append(card)
				_deck_changed()
	elif _side_index < CardLibrary.DECK_SIZE:
		if _side_index < _deck.size():
			_deck.remove_at(_side_index)
			_deck_changed()
	elif _side_index == CardLibrary.DECK_SIZE:
		_deck = CardLibrary.default_deck(_weapon)
		_deck_changed()
		_say("Deck reset to the default.", Color(0.55, 0.85, 1.0))
	else:
		_try_close()
	_refresh()

## Saves complete decks right away; an incomplete one just waits.
func _deck_changed() -> void:
	_leave_warned = false
	_status.text = ""
	_deck.sort_custom(func(a, b): return _collection.find(a) < _collection.find(b))
	if CardLibrary.deck_problem(_deck, _weapon) == "":
		Progress.set_starting_deck(_weapon, _deck)
		_say("Starting deck saved.", Color(0.55, 0.85, 1.0))

func _say(text: String, color := ERROR) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)

func _pulse(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * 1.06, 0.08)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)

# ---------------------------------------------------------------- Cursor

func _move_cursor_to(zone: Zone, index: int, scroll := true) -> void:
	_zone = zone
	if zone == Zone.GRID:
		_grid_index = clampi(index, 0, _cards.size() - 1)
		if scroll:
			_scroll.ensure_control_visible(_slots[_grid_index])
	else:
		_side_index = clampi(index, 0, _side_buttons.size() - 1)
	_update_cursor()
	_show_detail()

func _update_cursor() -> void:
	for i in _cards.size():
		_cards[i].set_focused(_zone == Zone.GRID and i == _grid_index)
	for i in _side_buttons.size():
		var button := _side_buttons[i]
		if _zone == Zone.SIDE and i == _side_index:
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

func _step(dx: int, dy: int) -> void:
	if _zone == Zone.GRID:
		var col := _grid_index % COLUMNS
		if dx > 0 and (col == COLUMNS - 1 or _grid_index == _cards.size() - 1):
			_move_cursor_to(Zone.SIDE, 0)
		elif dx != 0:
			_move_cursor_to(Zone.GRID, _grid_index + dx if col + dx >= 0 else _grid_index)
		elif _grid_index + dy * COLUMNS >= 0 and _grid_index + dy * COLUMNS < _cards.size():
			_move_cursor_to(Zone.GRID, _grid_index + dy * COLUMNS)
	else:
		if dx < 0:
			# Back to the collection's right edge, on the row in view.
			var first_visible := int(_scroll.scroll_vertical / maxf(_slots[0].size.y + 6, 1.0)) * COLUMNS
			_move_cursor_to(Zone.GRID, mini(first_visible + COLUMNS - 1, _cards.size() - 1))
		elif dy != 0:
			_move_cursor_to(Zone.SIDE, wrapi(_side_index + dy, 0, _side_buttons.size()))

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var handled := true
	if event.physical_keycode == KEY_ESCAPE and not event.echo:
		_try_close()
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("card_prev", true):
		_step(-1, 0)
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("card_next", true):
		_step(1, 0)
	elif event.is_action_pressed("ui_up", true) or event.physical_keycode == KEY_W:
		_step(0, -1)
	elif event.is_action_pressed("ui_down", true) or event.physical_keycode == KEY_S:
		_step(0, 1)
	elif not event.echo and (event.is_action_pressed("ui_accept") or event.is_action_pressed("card_select") \
			or event.is_action_pressed("card_execute")):
		_activate()
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()

## An incomplete deck isn't saved: warn once, then leave on the second try.
func _try_close() -> void:
	if CardLibrary.deck_problem(_deck, _weapon) != "" and not _leave_warned:
		_leave_warned = true
		_say("Deck not complete: runs keep using your last complete deck. Back again to leave anyway.")
		return
	closed.emit()
	queue_free()
