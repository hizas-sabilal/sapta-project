extends Node

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	BATTLE
}

var state: GameState
var current_enemy: EnemyData

func init_game() -> void:
	state = GameState.MENU
	print("Game started! To main menu... ")
	UiManager.show_main_menu()

func start_game() -> void:
	if state != GameState.MENU:
		return
	state = GameState.PLAYING
	RunManager.start_new_run()
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

## The overworld monster that started the current battle (removed on victory).
var battle_monster: Node

func enter_battle(enemies: PackedStringArray, monster: Node = null) -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.BATTLE
	battle_monster = monster
	SceneManager.battle_triggered(enemies)

func end_battle(won: bool) -> void:
	if state != GameState.BATTLE:
		return
	if won and not RunManager.is_boss_room():
		SceneManager.return_from_battle(battle_monster)
		battle_monster = null
		state = GameState.PLAYING
	else:
		# Lost, or beat the boss: the run is over either way.
		end_run()
		if won:
			_reward_room_clear() # Beating the boss clears the last room (toast over the menu).

## Every cleared room pays coins into the permanent bank.
func _reward_room_clear() -> void:
	var reward := Progress.room_clear_reward()
	Progress.add_coins(reward)
	UiManager.show_toast("Room cleared!  +%d coins" % reward)

## Iris ran out of HP outside a battle (traps). Same outcome as losing a fight.
func player_killed() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.MENU # Blocks pausing and battles while the message shows.
	_set_player_frozen(true)
	await UiManager.show_message("YOU DIED", 2.0)
	end_run()

func end_run() -> void:
	battle_monster = null
	SceneManager.clear_game()
	state = GameState.MENU
	UiManager.show_main_menu()

## Player walked into an unlocked exit.
func reach_exit() -> void:
	if state != GameState.PLAYING:
		return
	_set_player_frozen(true)
	_reward_room_clear()
	var next_room: Dictionary = await UiManager.choose_path(RunManager.get_next_room_choices())
	RunManager.advance_to(next_room)
	await SceneManager.start_room()

## Player opened a chest.
func open_treasure() -> void:
	if state != GameState.PLAYING:
		return
	_set_player_frozen(true)
	await UiManager.choose_card_reward("Treasure! Choose a card")
	_set_player_frozen(false)

## Stops exploration movement while a menu is open.
func _set_player_frozen(frozen: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		player.velocity = Vector2.ZERO
		player.set_physics_process(not frozen)
		if frozen and player.has_node("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").play("Idle")
