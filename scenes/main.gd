extends Node

@onready var level_container = $LevelContainer
@onready var ui_container = $UserInterfaceContainer
@onready var overlay_container = $OverlayContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.initialize(level_container)
	UiManager.initialize(ui_container, overlay_container)
	GameManager.init_game()
