class_name GameState
extends Node

signal game_state_changed(new_state: GameStates)
signal game_paused
signal game_resumed
signal game_overed

enum GameStates {
	STARTUP,
	MAIN_MENU,
	PLAYING,
	PAUSED,
	CUTSCENE,
	GAME_OVER,
}

var current_state: GameStates
var elapsed_time: float = 0.0

func _process(delta: float) -> void:
	Services.debug.add_debug_label(&"FPS", Engine.get_frames_per_second(), 20)
	if _state_check(GameStates.PLAYING):
		elapsed_time += delta
		Services.debug.add_debug_label(&"ElapsedTime", "%02d:%02d:%02d" % [
			int(elapsed_time / 3600),
			int(elapsed_time / 60) % 60,
			int(elapsed_time) % 60
		])
func change_game_state(new_state: GameStates) -> void:
	if _state_check(new_state): return
	
	current_state = new_state
	Services.debug.add_debug_label(&"GameState", GameStates.keys()[current_state])
	game_state_changed.emit(new_state)
	_on_state_changed(new_state)


func _on_state_changed(new_state: GameStates) -> void:
	match new_state:
		GameStates.STARTUP:
			_startup_state()
		GameStates.MAIN_MENU:
			Services.debug.add_debug_button(&"MainMenu", func(): Services.scene_loader.load_scene(SceneLoader.Scenes.MAIN_MENU))
			_main_menu_state()
		GameStates.PLAYING:
			_playing_state()
		GameStates.PAUSED:
			_paused_state()
		GameStates.CUTSCENE:
			_cutscene_state()
		GameStates.GAME_OVER:
			_game_over_state()


func _startup_state() -> void:
	get_tree().paused = false


func _main_menu_state() -> void:
	Services.debug.remove_debug_property("ElapsedTime")
	get_tree().paused = false


func _playing_state() -> void:
	Services.debug.add_debug_label("ElapsedTime", "%02d:%02d:%02d" % [int(elapsed_time / 60.0), int(elapsed_time) % 60, int(fmod(elapsed_time, 1.0) * 100)])
	get_tree().paused = false


func _paused_state() -> void:
	get_tree().paused = true


func _cutscene_state() -> void:
	get_tree().paused = false


func _game_over_state() -> void:
	get_tree().paused = false


func toggle_pause() -> void:
	if _state_check(GameStates.PLAYING):
		game_paused.emit()
		change_game_state(GameStates.PAUSED)
		return
	if _state_check(GameStates.PAUSED):
		game_resumed.emit()
		change_game_state(GameStates.PLAYING)
		return


func game_over() -> void:
	game_overed.emit()
	change_game_state(GameStates.GAME_OVER)

#Helpers
func _state_check(state: GameStates) -> bool:
	return current_state == state
