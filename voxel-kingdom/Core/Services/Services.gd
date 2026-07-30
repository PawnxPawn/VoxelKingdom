


extends Node

var game_state: GameState
var scene_loader: SceneLoader
var ui: UI
var debug: Debug
var audio: Audio
var globals: Globals





func _ready() -> void :
	get_tree().set_auto_accept_quit(false)
	_register_services()
	debug.add_debug_label(
		&"GameState", 
		game_state.GameStates.keys()[game_state.current_state]
	)





func _register_services() -> void :
	game_state = GameState.new()
	add_child(game_state)

	scene_loader = SceneLoader.new()
	ui = UI.new()

	audio = Audio.new()
	add_child(audio)


	debug = Debug.new()
	add_child(debug)
	
	globals = Globals.new()






func _deregister_service() -> void :
	pass





func set_ui_manager(ui_manager: Node) -> void :
	ui.ui_manager = ui_manager




func set_audio_manager(audio_manager: Node) -> void :
	audio.audio_manager = audio_manager




func set_scene_manager(scene_manager: Node) -> void :
	scene_loader.scene_manager = scene_manager


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		scene_loader.quit()
