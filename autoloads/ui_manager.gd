extends Node

var _ui_container: Node
var _overlay_container: Node
var _main_menu: Control
var _pause_menu: Control

const MAIN_MENU_SCENE = preload("res://scenes/menus/main_menu.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/menus/pause_menu.tscn")

func initialize(ui_container: Node, overlay_container: Node) -> void:
	_ui_container = ui_container
	_overlay_container = overlay_container
	
func show_main_menu() -> void:
	if _main_menu:
		return
	_main_menu = MAIN_MENU_SCENE.instantiate()
	_overlay_container.add_child(_main_menu)

func hide_main_menu() -> void:
	if not _main_menu:
		return
	_main_menu.queue_free()
	_main_menu = null

func show_pause_menu() -> void:
	if _pause_menu:
		return
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_overlay_container.add_child(_pause_menu)

func hide_pause_menu() -> void:
	if not _pause_menu:
		return
	_pause_menu.queue_free()
	_pause_menu = null
