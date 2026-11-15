extends Node

var level_container: Node

## The exploration level, kept alive (but out of the tree) during a battle
## so the player's position and the world state survive the fight.
var _stashed_level: Node
var _battle_scene: Node

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const LEVEL_001 := "res://scenes/levels/level_001.tscn"
const BATTLE_SCENE := "res://scenes/battles/battle_scene.tscn"

func initialize(container: Node):
	level_container = container

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

const EXPLORATION_TUTORIAL := preload("res://scenes/ui/exploration_tutorial.gd")

func start_game() -> void:
	await start_room()

## Loads a fresh copy of the level and fills it in for RunManager.current_room.
func start_room() -> void:
	var level = await change_level(LEVEL_001)
	RoomBuilder.build(level, RunManager.current_room)
	if RunManager.room_index == 0 and EXPLORATION_TUTORIAL.should_show():
		# Child of the level, so it hides during battles along with the level.
		level.add_child(EXPLORATION_TUTORIAL.new())

func change_level(scene_path: String) -> Node:
	_clear_container()
	_free_stashed_level()

	await get_tree().process_frame

	var scene = load(scene_path).instantiate()
	level_container.add_child(scene)
	return scene

func battle_triggered(enemies: PackedStringArray):
	# Triggered from body_entered; physics nodes can't leave the tree mid-callback.
	await get_tree().process_frame

	# Take the level out of the tree without freeing it.
	for child in level_container.get_children():
		level_container.remove_child(child)
		_stashed_level = child

	var scene = load(BATTLE_SCENE).instantiate()
	scene.set_enemies(enemies)
	_battle_scene = scene
	level_container.add_child(scene)

## Win: drop the battle and put the exploration level back.
func return_from_battle(defeated_monster: Node) -> void:
	_free_battle_scene()
	if is_instance_valid(defeated_monster):
		# Detach first so its BattleTrigger can't fire again when the level re-enters.
		defeated_monster.get_parent().remove_child(defeated_monster)
		defeated_monster.queue_free()
	if _stashed_level:
		level_container.add_child(_stashed_level)
		_stashed_level = null

## Lose: throw away the battle and the level.
func clear_game() -> void:
	_free_battle_scene()
	_free_stashed_level()
	_clear_container()

func _free_battle_scene() -> void:
	if is_instance_valid(_battle_scene):
		_battle_scene.queue_free()
	_battle_scene = null

func _free_stashed_level() -> void:
	if is_instance_valid(_stashed_level):
		_stashed_level.queue_free()
	_stashed_level = null

func _clear_container() -> void:
	for child in level_container.get_children():
		child.queue_free()
