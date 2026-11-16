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

## Shows the next-room choice and waits for the pick.
func choose_path(options: Array[Dictionary]) -> Dictionary:
	var screen := PathChoice.new()
	screen.options = options
	_ui_container.add_child(screen)
	return await screen.chosen

## Shows a card reward and waits; returns the picked card or null if skipped.
func choose_card_reward(title: String = "",
		discovery_chance := CardLibrary.BATTLE_DISCOVERY_CHANCE) -> CardData:
	var screen := CardRewardScreen.new()
	screen.discovery_chance = discovery_chance
	if title != "":
		screen.title_text = title
	_ui_container.add_child(screen)
	return await screen.finished

## Offers a found weapon; returns true if the player takes it.
func choose_weapon(weapon: WeaponData) -> bool:
	var screen := WeaponFindScreen.new()
	screen.weapon = weapon
	_ui_container.add_child(screen)
	return await screen.finished

## Big centered text over the game for `seconds`; await it to wait it out.
func show_message(text: String, seconds: float) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	_ui_container.add_child(label)
	await get_tree().create_timer(seconds).timeout
	label.queue_free()

## Short gold notice near the top of the screen that fades out on its own.
func show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = 90
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The overlay layer stays up across scene changes (path choice, main menu).
	_overlay_container.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func hide_pause_menu() -> void:
	if not _pause_menu:
		return
	_pause_menu.queue_free()
	_pause_menu = null
