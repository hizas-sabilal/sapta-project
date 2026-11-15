extends Node2D

var deck = []
var hand = []
var card_scene = preload("res://scenes/battles/card_ui.tscn")

@onready var enemy_container = $EnemyContainer
@onready var hand_container = $CanvasLayer/BattleUI/CenterContainer/HandContainer
@onready var execute_button = $CanvasLayer/BattleUI/ExecuteButton
@onready var battle_ui = $CanvasLayer/BattleUI
@onready var player = $PlayerBattle

# Store references to enemies
var enemies_to_spawn: PackedStringArray = []
var enemy: Node2D # Represents the active enemy

var selected_cards = []
var discard_pile = []

const MAX_CARD_IN_HAND = 3
const ACTION_POINT = 3
## AP per turn, including the Adrenaline skill.
var max_ap := ACTION_POINT + Progress.bonus("adrenaline")
const RESULT_SCREEN_SECONDS = 2.0
var used_AP := 0

## True while cards / enemy turn are resolving, so input is ignored.
var busy := false
var battle_over := false

var player_hp_bar: HpBar
var ap_dots: ApDots
var enemy_name_label: Label
var enemy_hp_bar: HpBar
var enemy_intent_label: Label
var enemy_status_label: Label
var _popup_stack := {} ## Fighter -> popups currently rising above it.

## Keyboard cursor over the hand. Only shown once a card key is pressed,
## so mouse players don't see a stray highlight.
var _focus_index := 0
var _show_focus := false
var _keys_hint: Label


# 1. Configuration method called BEFORE adding to scene tree
func set_enemies(enemies: PackedStringArray) -> void:
	enemies_to_spawn = enemies

# 2. Initialization is handled once in the tree
func _ready() -> void:
	# Exploration now uses a scrolling camera; give the battle its own fixed one.
	var camera := Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()

	hand_container.add_theme_constant_override("separation", 18)
	_create_keys_hint()
	setup_deck()
	player.setup(RunManager.hp, RunManager.max_hp)
	_create_status_labels()

	# Spawn the configured enemies
	_spawn_enemies()

	# Start game loop
	if player and enemy:
		start_player_turn()
	else:
		push_error("Failed to initialize player or enemy correctly.")

func _spawn_enemies() -> void:
	if enemies_to_spawn.is_empty():
		push_error("No enemies configured to spawn!")
		return

	var enemy_key = enemies_to_spawn[0].strip_edges() # Grab the first enemy safely

	# Safe guard dictionary lookup
	if not Constants.ENEMIES.has(enemy_key):
		push_error("Enemy key '%s' not found in Constants.ENEMIES" % enemy_key)
		return

	var enemy_path = Constants.ENEMIES[enemy_key]
	var enemy_scene = load(enemy_path)

	if enemy_scene:
		var enemy_instance = enemy_scene.instantiate()
		if enemy_container:
			enemy_container.add_child(enemy_instance)
			enemy = enemy_instance
			_apply_run_modifiers()
		else:
			push_error("EnemyContainer node is missing in the scene tree!")
	else:
		push_error("Failed to load enemy scene at path: " + enemy_path)

## Enemies get tougher deeper into the run; the boss gets its own boost.
func _apply_run_modifiers() -> void:
	var hp_scale: float = RunManager.enemy_hp_scale()
	if RunManager.is_boss_room():
		enemy.apply_modifiers(hp_scale * RunManager.BOSS_HP_MULTIPLIER,
			RunManager.BOSS_DAMAGE_BONUS, RunManager.BOSS_NAME)
		enemy.modulate = RoomBuilder.BOSS_TINT
	else:
		enemy.apply_modifiers(hp_scale)

func setup_deck() -> void:
	# Copy, so drawing/discarding during battle never touches the run's deck.
	deck = RunManager.deck.duplicate()
	deck.shuffle()

## Status panels in the top corners (the hand sits top-center):
## name, HP bar (with block badge) and AP dots for Iris; name, HP bar,
## intent and status effects for the enemy.
func _create_status_labels() -> void:
	var left := _status_box(Vector2(48, 16))
	left.add_child(_title_label("Iris"))
	player_hp_bar = HpBar.new()
	player_hp_bar.custom_minimum_size = Vector2(280, 28)
	left.add_child(player_hp_bar)
	var ap_row := HBoxContainer.new()
	ap_row.add_theme_constant_override("separation", 10)
	ap_row.add_child(_small_label("AP"))
	ap_dots = ApDots.new()
	ap_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ap_row.add_child(ap_dots)
	left.add_child(ap_row)

	var right := _status_box(Vector2(1280 - 24 - 280, 16))
	enemy_name_label = _title_label("")
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(enemy_name_label)
	enemy_hp_bar = HpBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(280, 28)
	right.add_child(enemy_hp_bar)
	enemy_intent_label = _small_label("")
	enemy_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(enemy_intent_label)
	enemy_status_label = _small_label("")
	enemy_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_status_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	right.add_child(enemy_status_label)

func _status_box(at: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = at
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_ui.add_child(box)
	return box

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label

func _small_label(text: String) -> Label:
	var label := _title_label(text)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("outline_size", 4)
	return label

func _process(_delta: float) -> void:
	if player_hp_bar:
		player_hp_bar.set_values(player.hp, player.max_hp, player.block)
		ap_dots.set_values(max_ap - used_AP, max_ap)
	if enemy_hp_bar and enemy:
		enemy_name_label.text = enemy.enemy_name
		enemy_hp_bar.set_values(enemy.current_hp, enemy.max_hp)
		enemy_intent_label.text = _intent_text()
		enemy_status_label.text = _enemy_status_text()

func _intent_text() -> String:
	if battle_over or enemy.is_dead():
		return ""
	if enemy.weaken > 0:
		return "Intent: Attack %d  (-%d = %d)" % [enemy.intent_damage, enemy.weaken, enemy.planned_damage()]
	return "Intent: Attack %d" % enemy.intent_damage

func _enemy_status_text() -> String:
	var parts: PackedStringArray = []
	if enemy.bleed > 0:
		parts.append("Bleed %d" % enemy.bleed)
	if enemy.expose > 0:
		parts.append("Exposed %d" % enemy.expose)
	return "   ".join(parts)

## One-line reminder of the card keys, under the Action! button.
func _create_keys_hint() -> void:
	_keys_hint = Label.new()
	# The Action! key is on the button's own badge.
	_keys_hint.text = "%s  |  %s: choose card      %s: select" % [
		Settings.describe("card_prev"), Settings.describe("card_next"),
		Settings.describe("card_select")]
	_keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys_hint.add_theme_font_size_override("font_size", 15)
	_keys_hint.add_theme_constant_override("outline_size", 4)
	_keys_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_keys_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_hint.position = Vector2(0, 370)
	_keys_hint.size = Vector2(1280, 24)
	battle_ui.add_child(_keys_hint)

func _unhandled_input(event: InputEvent) -> void:
	if busy or battle_over or not (event is InputEventKey):
		return
	if event.is_action_pressed("card_prev", true):
		_move_focus(-1)
	elif event.is_action_pressed("card_next", true):
		_move_focus(1)
	elif event.is_action_pressed("card_select"):
		if not hand.is_empty():
			_show_focus = true
			select_card(hand[_focus_index])
	elif event.is_action_pressed("card_execute"):
		_on_execute_button_pressed()
	else:
		var slot := _card_slot_pressed(event)
		if slot < 0:
			return # Not a card key; leave it for others.
		if slot < hand.size():
			_focus_index = slot
			_show_focus = true
			select_card(hand[slot])
	get_viewport().set_input_as_handled()

## Index of the "Card N" key in this event, or -1.
func _card_slot_pressed(event: InputEvent) -> int:
	for i in MAX_CARD_IN_HAND:
		if event.is_action_pressed("card_%d" % (i + 1)):
			return i
	return -1

func _move_focus(step: int) -> void:
	if hand.is_empty():
		return
	if _show_focus:
		_focus_index = wrapi(_focus_index + step, 0, hand.size())
	_show_focus = true # First press just reveals the cursor where it is.
	_update_focus()

func _update_focus() -> void:
	_focus_index = clampi(_focus_index, 0, maxi(hand.size() - 1, 0))
	for i in hand.size():
		hand[i].set_focused(_show_focus and not busy and not battle_over and i == _focus_index)

func draw_hand():
	while hand.size() < MAX_CARD_IN_HAND:
		if deck.is_empty():
			if discard_pile.is_empty():
				break
			# Reshuffle the discard pile back into the deck.
			deck = discard_pile.duplicate()
			discard_pile.clear()
			deck.shuffle()
			print("Reshuffled discard pile into deck")

		var card_data = deck.pop_front()
		var card_ui = card_scene.instantiate()
		card_ui.data = card_data
		card_ui.clicked.connect(select_card)
		hand.append(card_ui)
		hand_container.add_child(card_ui)
	_refresh_playable()

## Dims cards that don't fit in the AP left this turn.
func _refresh_playable() -> void:
	for card in hand:
		card.set_playable(not busy and used_AP + card.data.cost <= max_ap)
	execute_button.set_state(selected_cards.size(), used_AP, max_ap)

func _set_busy(value: bool) -> void:
	busy = value
	execute_button.disabled = value
	_refresh_playable()
	_update_focus()

func start_player_turn():
	used_AP = 0
	player.reset_block() # Block only lasts through the enemy's next attack.
	if Progress.bonus("guard") > 0: # Skill tree.
		player.add_block(Progress.bonus("guard"))
	enemy.roll_intent()
	draw_hand()
	_set_busy(false)

func select_card(card):
	if busy or battle_over:
		return
	_focus_index = maxi(hand.find(card), 0) # Mouse clicks move the cursor too.
	_update_focus()

	if card.selected:
		selected_cards.erase(card)
		card.set_selected(false)
		used_AP -= card.data.cost
	elif used_AP + card.data.cost <= max_ap:
		used_AP += card.data.cost
		selected_cards.append(card)
		card.set_selected(true)
	else:
		_popup(ap_dots.get_global_rect().get_center() + Vector2(0, 30), "Not enough AP", Color(1, 0.6, 0.4))
	_refresh_playable()

func _on_execute_button_pressed() -> void:
	if busy or battle_over:
		return
	execute_turn()

## Plays the selected cards in the order they were picked.
func execute_turn():
	_set_busy(true)

	for card in selected_cards:
		await _play_card(card.data)
		if enemy.is_dead():
			break # Remaining cards are not needed.
		await get_tree().create_timer(0.25).timeout

	# Remove executed cards
	for card in selected_cards:
		discard_pile.append(card.data)
		hand.erase(card)
		card.queue_free()
	selected_cards.clear()

	if enemy.is_dead():
		await enemy.die()
		_end_battle(true)
		return

	enemy.tick_expose()
	enemy_turn()

## Applies one card's effects in CardData order: damage (x hits, with
## lifesteal), block, heal, bleed, weaken, expose. Stops early if the enemy dies.
func _play_card(data: CardData) -> void:
	print("Play ", data.card_name)

	if data.damage > 0:
		for i in data.hits:
			var dealt: int = enemy.take_hit(data.damage + Progress.bonus("sharpness"))
			_popup_at(enemy, "-%d" % dealt, Color(1, 0.35, 0.3))
			if data.lifesteal > 0:
				var restored: int = player.heal(int(dealt * data.lifesteal / 100.0))
				if restored > 0:
					_popup_at(player, "+%d HP" % restored, Color(0.5, 1, 0.55))
			await player.play_attack()
			if enemy.is_dead():
				return
			await enemy.play_hurt()

	if data.block > 0:
		player.add_block(data.block)
		_popup_at(player, "+%d Block" % data.block, Color(0.55, 0.75, 1))

	if data.heal > 0:
		var healed: int = player.heal(data.heal)
		_popup_at(player, "+%d HP" % healed, Color(0.5, 1, 0.55))

	if data.bleed > 0:
		enemy.bleed += data.bleed
		_popup_at(enemy, "Bleed +%d" % data.bleed, Color(1, 0.3, 0.35))

	if data.weaken > 0:
		enemy.weaken += data.weaken
		_popup_at(enemy, "Weakened -%d" % data.weaken, Color(0.8, 0.6, 1))

	if data.expose > 0:
		enemy.expose += data.expose
		_popup_at(enemy, "Exposed", Color(0.8, 0.6, 1))

func enemy_turn():
	# Bleed hurts before the enemy can act.
	var bled: int = enemy.tick_bleed()
	if bled > 0:
		_popup_at(enemy, "-%d Bleed" % bled, Color(1, 0.3, 0.35))
		if enemy.is_dead():
			await enemy.die()
			_end_battle(true)
			return
		await enemy.play_hurt()

	var damage: int = enemy.attack()
	print("Enemy attacks: ", damage)

	var blocked: int = min(player.block, damage)
	var lost: int = player.take_damage(damage)
	await enemy.play_attack()
	if blocked > 0:
		_popup_at(player, "Blocked %d" % blocked, Color(0.55, 0.75, 1))
	if lost > 0 or blocked == 0:
		_popup_at(player, "-%d" % lost, Color(1, 0.35, 0.3))

	if player.is_dead():
		await player.die()
		_end_battle(false)
		return

	if lost > 0:
		await player.play_hurt()
	await get_tree().create_timer(0.8).timeout
	start_player_turn()

## Floating combat text above a fighter. Popups fired close together stack upward.
func _popup_at(target: Node2D, text: String, color: Color) -> void:
	var stack: int = _popup_stack.get(target, 0)
	_popup_stack[target] = stack + 1
	var above := target.get_global_transform_with_canvas().origin + Vector2(0, -170 - stack * 30)
	_popup(above, text, color)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(target):
		_popup_stack[target] = maxi(_popup_stack.get(target, 1) - 1, 0)

func _popup(screen_pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_ui.add_child(label)
	label.position = screen_pos - label.get_combined_minimum_size() / 2.0
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)

func _end_battle(won: bool) -> void:
	battle_over = true
	_set_busy(true)
	hand_container.hide()
	execute_button.hide()
	_keys_hint.hide()
	RunManager.hp = player.hp # Damage carries over to the next fight.

	var boss: bool = RunManager.is_boss_room()
	var text := "YOU DIED"
	if won:
		text = "RUN COMPLETE!" if boss else "VICTORY"
	var result := _show_result(text)
	await get_tree().create_timer(RESULT_SCREEN_SECONDS * (2.0 if boss else 1.0)).timeout

	if won:
		RunManager.battles_won += 1
		if not boss: # No reward after the boss; the run is over.
			result.queue_free()
			var reward := CardRewardScreen.new()
			battle_ui.add_child(reward)
			await reward.finished

	GameManager.end_battle(won)

func _show_result(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_ui.add_child(label)
	return label
