extends Node

var level_container: Node

const MAIN_MENU := "res://scenes/main_menu.tscn"
const LEVEL_001 := "res://scenes/levels/level_001.tscn"
const BATTLE_SCENE := "res://scenes/battles/battle_scene.tscn"

func initialize(container: Node):
		level_container = container

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

func start_game() -> void:
	change_level(LEVEL_001)

func change_level(scene_path: String):
	for child in level_container.get_children():
		child.queue_free()

	await get_tree().process_frame
	
	var scene = load(scene_path).instantiate()
	level_container.add_child(scene)
	
func battle_triggered():
	change_level(BATTLE_SCENE)
