extends Node

var game_state: GameState
var scene_loader: SceneLoader
var ui: UI
var debug: Debug
#var audio_services

func _ready() -> void:
	_register_services()
	debug.add_debug_label(&"GameState", game_state.GameStates.keys()[game_state.current_state])


func _register_services() -> void:
	game_state = GameState.new()
	add_child(game_state)
	
	scene_loader = SceneLoader.new()
	ui = UI.new()
	
	debug = Debug.new()
	add_child(debug)


func _deregister_service() -> void:
	pass


func set_ui_manager(ui_manager:Node):
	ui.ui_manager = ui_manager


func set_scene_manager(scene_manager:Node):
	scene_loader.scene_manager = scene_manager
