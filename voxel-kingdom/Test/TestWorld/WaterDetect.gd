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

const HYSTERESIS_MARGIN: float = 0.15

var _feet_submerged: bool = false
var _head_submerged: bool = false


func _physics_process(_delta: float) -> void:
	if chunk_manager == null:
		return
	
	_check_point(feet_point.global_position, true)
	_check_point(head_point.global_position, false)


func _check_point(pos: Vector3, is_feet: bool) -> void:
	var currently_submerged: bool = _feet_submerged if is_feet else _head_submerged
	
	var biased_y: float = pos.y - HYSTERESIS_MARGIN if currently_submerged else pos.y + HYSTERESIS_MARGIN
	
	var voxel: Vector3i = Vector3i(
		roundi(pos.x),
		roundi(biased_y),
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
