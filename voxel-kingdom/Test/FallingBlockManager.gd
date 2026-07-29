class_name FallingBlockManager
extends Node

@export var chunk_manager: ChunkManager

var _pending: Dictionary = {}
var _accum: float = 0.0
const STEP_INTERVAL: float = 0.08 


func queue_check(pos: Vector3i) -> void:
	_pending[pos] = true


func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < STEP_INTERVAL:
		return
	_accum = 0.0

	if _pending.is_empty():
		return

	var batch: Array = _pending.keys()
	_pending.clear()

	for pos in batch:
		_process_fall(pos)


func _process_fall(pos: Vector3i) -> void:
	var type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(pos)
	if not TerrianData.is_fallable(type):
		return

	var below_pos: Vector3i = pos + Vector3i.DOWN
	var below_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(below_pos)

	if not TerrianData.is_fall_passable(below_type):
		return
	
	chunk_manager.set_voxel_type_at(below_pos, type)
	chunk_manager.set_voxel_type_at(pos, below_type)

	queue_check(below_pos)

	if TerrianData.is_water(below_type) or TerrianData.is_lava(below_type):
		queue_check(pos)
