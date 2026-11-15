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
const RESULT_SCREEN_SECONDS = 2.0
var used_AP := 0

## True while cards / enemy turn are resolving, so input is ignored.
var busy := false
var battle_over := false

var player_status: Label
var enemy_status: Label


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

## HP / block / AP readouts in the top corners (the hand sits top-center).
func _create_status_labels() -> void:
	player_status = Label.new()
	player_status.position = Vector2(24, 20)
	player_status.add_theme_font_size_override("font_size", 24)
	battle_ui.add_child(player_status)

	enemy_status = Label.new()
	enemy_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	enemy_status.offset_left = -340
	enemy_status.offset_right = -24
	enemy_status.offset_top = 20
	enemy_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_status.add_theme_font_size_override("font_size", 24)
	battle_ui.add_child(enemy_status)

func _process(_delta: float) -> void:
	if player_status:
		player_status.text = "Iris\nHP %d/%d\nBlock %d\nAP %d/%d" % [
			player.hp, player.max_hp, player.block, ACTION_POINT - used_AP, ACTION_POINT]
	if enemy_status and enemy:
		enemy_status.text = "%s\nHP %d/%d" % [enemy.enemy_name, enemy.current_hp, enemy.max_hp]

func draw_hand():
	while hand.size() < MAX_CARD_IN_HAND:
		if deck.is_empty():
			if discard_pile.is_empty():
				return
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

func _set_busy(value: bool) -> void:
	busy = value
	execute_button.disabled = value

func start_player_turn():
	used_AP = 0
	player.reset_block() # Block only lasts through the enemy's next attack.
	draw_hand()
	_set_busy(false)

func select_card(card):
	if busy or battle_over:
		return

	if card.selected:
		selected_cards.erase(card)
		card.set_selected(false)
		used_AP -= card.data.cost
		print("usedAP:", used_AP)
		return

	if used_AP + card.data.cost <= ACTION_POINT:
		used_AP += card.data.cost
		selected_cards.append(card)
		card.set_selected(true)
		print("Selected:", card.data.card_name)
		print("usedAP:", used_AP)
	else:
		print("Not enough AP")

func _on_execute_button_pressed() -> void:
	if busy or battle_over:
		return
	execute_turn()

func execute_turn():
	_set_busy(true)
	print("EXECUTE TURN")

	for card in selected_cards:
		var data: CardData = card.data
		print(data.card_name)

		if data.damage > 0:
			enemy.take_damage(data.damage)
			await player.play_attack()
			if enemy.is_dead():
				await enemy.die()
				break # Remaining cards are not needed.
			await enemy.play_hurt()

		if data.block > 0:
			player.add_block(data.block)

		if data.heal > 0:
			player.heal(data.heal)

	# Remove executed cards
	for card in selected_cards:
		discard_pile.append(card.data)
		hand.erase(card)
		card.queue_free()
	selected_cards.clear()

	if enemy.is_dead():
		_end_battle(true)
		return

	enemy_turn()

func enemy_turn():
	var damage = enemy.attack()
	print("Enemy attacks: ", damage)

	player.take_damage(damage)
	await enemy.play_attack()

	if player.is_dead():
		await player.die()
		_end_battle(false)
		return

	await player.play_hurt()
	await get_tree().create_timer(1.0).timeout
	start_player_turn()

func _end_battle(won: bool) -> void:
	battle_over = true
	_set_busy(true)
	hand_container.hide()
	execute_button.hide()
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
