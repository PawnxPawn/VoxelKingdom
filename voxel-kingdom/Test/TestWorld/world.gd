extends Node3D

var cubes: int = 0
var data: Dictionary[Vector3, Color] = {}

func _ready() -> void:
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	Performance.add_custom_monitor(&"Game/Cubes", func(): return cubes)
