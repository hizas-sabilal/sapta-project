extends Control

@onready var _start_button: Button = $Panel/CenterContainer/VBoxContainer/StartButton
@onready var _options_button: Button = $Panel/CenterContainer/VBoxContainer/OptionsButton

func _ready() -> void:
	_start_button.grab_focus() # Lets the menu be driven with arrow keys + Enter.

func _on_start_button_pressed() -> void:
	GameManager.start_game()

func _on_options_button_pressed() -> void:
	var options := OptionsMenu.new()
	options.closed.connect(_options_button.grab_focus)
	add_child(options)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
