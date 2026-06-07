extends Node

enum GameState {
	MENU,
	PLAYING,
	PAUSED
}

var state: GameState

func init_game() -> void:
	state = GameState.MENU
	print("Game started! To main menu... ")
	UiManager.show_main_menu()

func start_game() -> void:
	if state != GameState.MENU:
		return
	state = GameState.PLAYING
	await SceneManager.start_game()
	await UiManager.hide_main_menu()


func pause_game() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	get_tree().paused = true
	UiManager.show_pause_menu()


func resume_game() -> void:
	if state != GameState.PAUSED:
		return
	state = GameState.PLAYING
	get_tree().paused = false
	UiManager.hide_pause_menu()
#
#
#func toggle_pause() -> void:
#
	#if state == GameState.PLAYING:
		#pause_game()
#
	#elif state == GameState.PAUSED:
		#resume_game()
