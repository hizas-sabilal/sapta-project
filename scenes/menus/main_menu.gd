extends Control

@onready var _start_button: Button = $Panel/CenterContainer/VBoxContainer/StartButton
@onready var _skills_button: Button = $Panel/CenterContainer/VBoxContainer/SkillsButton
@onready var _options_button: Button = $Panel/CenterContainer/VBoxContainer/OptionsButton

var _coins_label: Label

func _ready() -> void:
	# Coin balance under the buttons (coins are kept between runs).
	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 24)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_coins_label.add_theme_constant_override("outline_size", 4)
	_coins_label.add_theme_color_override("font_outline_color", Color.BLACK)
	$Panel/CenterContainer/VBoxContainer.add_child(_coins_label)
	Progress.coins_changed.connect(_update_coins)
	_update_coins(Progress.coins)

	_start_button.grab_focus() # Lets the menu be driven with arrow keys + Enter.

func _update_coins(coins: int) -> void:
	_coins_label.text = "Coins: %d" % coins

func _on_start_button_pressed() -> void:
	GameManager.start_game()

func _on_skills_button_pressed() -> void:
	_open_screen(SkillTreeMenu.new(), _skills_button)

func _on_options_button_pressed() -> void:
	_open_screen(OptionsMenu.new(), _options_button)

## Opens a full-screen sub menu on top. The menu's own buttons stop taking
## focus meanwhile: they sit right behind the screen's middle, so arrow keys
## would otherwise move focus onto them (invisible) instead of the screen.
func _open_screen(screen: Control, return_to: Button) -> void:
	_set_buttons_focusable(false)
	screen.closed.connect(func():
		_set_buttons_focusable(true)
		return_to.grab_focus())
	add_child(screen)

func _set_buttons_focusable(value: bool) -> void:
	for child in $Panel/CenterContainer/VBoxContainer.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE

func _on_exit_button_pressed() -> void:
	get_tree().quit()
