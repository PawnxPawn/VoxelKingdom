#-###########################################
# WaterDetector
#-###########################################

class_name WaterDetector
extends Node

signal feet_submerged_changed(is_submerged: bool)
signal head_submerged_changed(is_submerged: bool)

@export var chunk_manager: ChunkManager
@export var feet_point: Node3D
@export var head_point: Node3D
@export var check_interval: float = 0.1

var _timer: float = 0.0
var _feet_submerged: bool = false
var _head_submerged: bool = false


func _process(delta: float) -> void:
	if chunk_manager == null:
		return
	
	_timer += delta
	if _timer < check_interval:
		return
	_timer = 0.0
	
	_check_point(feet_point.global_position, true)
	_check_point(head_point.global_position, false)


func _check_point(pos: Vector3, is_feet: bool) -> void:
	var voxel: Vector3i = Vector3i(
		roundi(pos.x),
		roundi(pos.y),
		roundi(pos.z)
	)
	
	var voxel_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(voxel)
	var submerged: bool = TerrianData.is_water(voxel_type)
	
	if is_feet:
		if submerged != _feet_submerged:
			_feet_submerged = submerged
			feet_submerged_changed.emit(submerged)
	else:
		if submerged != _head_submerged:
			_head_submerged = submerged
			head_submerged_changed.emit(submerged)
