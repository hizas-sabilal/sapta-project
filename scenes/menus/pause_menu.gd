extends Control

func _on_resume_button_pressed() -> void:
	get_tree().paused = false  # unpause FIRST
	print('Resume triggered')
	GameManager.resume_game()
