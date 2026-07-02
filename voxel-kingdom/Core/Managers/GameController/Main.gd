extends Node

@onready var scene_manager: Node = $SceneManager
@onready var ui_manager: CanvasLayer = $UIManager


func _ready() -> void:
	Services.set_scene_manager(scene_manager)
	Services.set_ui_manager(ui_manager)
	Services.scene_loader.load_scene(SceneLoader.Scenes.MAIN_MENU)
