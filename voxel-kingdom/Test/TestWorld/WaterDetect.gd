#-###########################################
# WaterDetector
#-###########################################

class_name WaterDetector
extends Node

signal submerged_changed(is_submerged: bool)

@export var chunk_manager: ChunkManager
@export var eye_point: Node3D
@export var check_interval: float = 0.1

var is_submerged: bool = false
var _timer: float = 0.0


#----------------
# Process
#----------------
func _process(delta: float) -> void:
	if chunk_manager == null or eye_point == null:
		return
		
	_timer += delta
	if _timer < check_interval:
		return
	_timer = 0.0
	
	var eye_position: Vector3 = eye_point.global_position
	
	var voxel_position: Vector3i = Vector3i(
		roundi(eye_position.x),
		roundi(eye_position.y),
		roundi(eye_position.z)
	)
	
	var voxel_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(voxel_position)
	var now_submerged: bool = TerrianData.is_water(voxel_type)
	
	if now_submerged != is_submerged:
		is_submerged = now_submerged
		submerged_changed.emit(is_submerged)
