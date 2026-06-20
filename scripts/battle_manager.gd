extends Node2D

var deck = []
var hand = []

var card_scene = preload("res://scenes/battles/card_ui.tscn")
var hand_container
var selected_cards = []

const MAX_CARD_IN_HAND = 3
const ACTION_POINT = 3
var used_AP := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#LOAD CARD DECK
	hand_container = $CanvasLayer/BattleUI/CenterContainer/HandContainer
	setup_deck()
	
	#START PLAYER TURN
	start_player_turn()
	


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

#TODO enemy turn

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
