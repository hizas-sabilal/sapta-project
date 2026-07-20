extends Node2D

var deck = []
var hand = []
var card_scene = preload("res://scenes/battles/card_ui.tscn")

@onready var enemy_container = $EnemyContainer
@onready var hand_container = $CanvasLayer/BattleUI/CenterContainer/HandContainer
@onready var player = $PlayerBattle

# Store references to enemies
var enemies_to_spawn: PackedStringArray = []
var enemy: Node2D # Represents the active enemy

var enemy_scene
var enemy_instance

var selected_cards = []
var discard_pile= []

const MAX_CARD_IN_HAND = 3
const ACTION_POINT = 3
var used_AP := 0

# 1. Configuration method called BEFORE adding to scene tree
func set_enemies(enemies: PackedStringArray) -> void:
	enemies_to_spawn = enemies
# 2. Initialization is handled once in the tree
func _ready() -> void:
	setup_deck()
	
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
		
	var enemy_key = enemies_to_spawn[0] # Grab the first enemy safely
	
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
			enemy = enemy_instance # Direct assignment! Safe and fast.
		else:
			push_error("EnemyContainer node is missing in the scene tree!")
	else:
		push_error("Failed to load enemy scene at path: " + enemy_path)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func setup_deck() -> void:
	deck = [
		preload("res://resources/cardsdata/bandage.tres"),
		preload("res://resources/cardsdata/block.tres"),
		preload("res://resources/cardsdata/slash.tres"),
		preload("res://resources/cardsdata/stab.tres"),
		preload("res://resources/cardsdata/double_stab.tres"),
	]
	deck.shuffle()

func draw_hand():
	while hand.size() < MAX_CARD_IN_HAND:
		if deck.is_empty():
			return
		
		var card_data = deck.pop_front()
		
		var card_ui = card_scene.instantiate()
		
		card_ui.data = card_data
		hand.append(card_ui)
		
		hand_container.add_child(card_ui)

func start_player_turn():
	used_AP = 0
	draw_hand()

func end_player_turn():
	enemy_turn()

func enemy_turn():
	var damage = enemy.attack()
	print("Enemy attacks: ", damage)

	player.take_damage(damage)
	await enemy.play_attack()
	await player.play_hurt()
	
	await get_tree().create_timer(1.0).timeout
	start_player_turn()

func select_card(card):
	
	if card.selected:
		selected_cards.erase(card)
		card.set_selected(false)
		used_AP -= card.data.cost
		
		print("usedAP:", used_AP)
		return
		
	if(used_AP < ACTION_POINT):
		used_AP += card.data.cost
		selected_cards.append(card)
		card.set_selected(true)
		
		print("Selected:", card.data.card_name)
		print("usedAP:", used_AP)
	else:
		print("Max AP")

func _on_execute_button_pressed() -> void:
	execute_turn()

func execute_turn():
	print("EXECUTE TURN")
	
	for card in selected_cards:
		print(card.data.card_name)
		print(card.data.damage)
		
		if(card.data.damage > 0):
			enemy.take_damage(card.data.damage)
			await player.play_attack()
			await enemy.play_hurt()
			
		if(card.data.heal > 0):
			player.heal(card.data.heal)
			
	#REMOVE EXECUTED CARD
	for card in selected_cards:
		discard_pile.append(card.data)
		hand.erase(card)
		card.queue_free()
	
	selected_cards.clear()
	end_player_turn()
