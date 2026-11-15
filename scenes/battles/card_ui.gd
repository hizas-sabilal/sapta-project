extends Panel

@export var data: CardData

@onready var nameCard = $VBoxContainer/NameLabel
@onready var costCard = $VBoxContainer/CostLabel
@onready var descCard = $VBoxContainer/Description

var selected := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		
	if data:
		nameCard.text = data.card_name
		costCard.text = str(data.cost)
		descCard.text = str(data.description)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Emitted with this card when left-clicked. Whoever spawns the card decides
## what a click means (select in hand, pick as reward, ...).
signal clicked(card)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func set_selected(value: bool):
	selected = value
	if selected:
		position.y = -20
	else:
		position.y = 0
		
