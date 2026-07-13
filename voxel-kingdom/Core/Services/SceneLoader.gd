#-###########################################
# Scene Loader
#-###########################################

class_name SceneLoader
extends Node

# OPTIONAL: Threaded loading, Level Streaming

enum Scenes {
	MAIN_MENU,
	TEST,
}

const _PRELOADED_SCENES: Dictionary = {
	# Scenes.MAIN_MENU: preload(""),
	# Scenes.TEST: preload(""),
}

const _DYNAMIC_SCENES: Dictionary = {
	# Level streaming placeholder
}

var scene_manager: Node = null
var is_transitioning: bool = false
var _loaded_scenes: Dictionary = {}


#----------------
# Load Scene
#----------------
func load_scene(scene: Scenes, transition: bool = true) -> void:
	if not scene_manager:
		push_error("SceneLoader: %s can't load because SceneManager is not set.")
		return
	
	if transition:
		is_transitioning = true
		
		_swap_scene(scene)
		
		transition = false
		is_transitioning = false
		
		Services.debug.add_debug_label(
			&"ScenesLoaded",
			(func() -> Array:
				var arr: Array = []
				for i in _loaded_scenes:
					arr.append(Scenes.keys()[i])
				return arr
				).call()
		)
		
		return
	
	_add_to_scene(scene)


#----------------
# Swap Scene
#----------------
func _swap_scene(scene: Scenes) -> void:
	if _loaded_scenes.has(scene):
		push_warning("SceneLoader: %s already is loaded." % Scenes.keys()[scene])
		return
	
	_clean_up()
	
	var instance: Node = _PRELOADED_SCENES[scene].instantiate()
	scene_manager.add_child(instance)
	_loaded_scenes[scene] = instance


#----------------
# Add Scene (Streaming Placeholder)
#----------------
func _add_to_scene(_scene: Scenes) -> void:
	pass
	# Placeholder for level streaming


#----------------
# Cleanup
#----------------
func _clean_up() -> void:
	if not _loaded_scenes.is_empty():
		for key in _loaded_scenes:
			_loaded_scenes[key].queue_free()
		
		_loaded_scenes.clear()


#----------------
# Scene Manager Check
#----------------
func _scene_manager_check() -> bool:
	if not scene_manager:
		push_error("SceneLoader: Can't load new scenes because scene_manager is not set.")
		return false
	
	return true
