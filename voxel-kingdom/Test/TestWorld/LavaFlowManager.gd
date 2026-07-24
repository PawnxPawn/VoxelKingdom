#-###########################################
# Lava Flow Manager
#-###########################################
class_name LavaFlowManager
extends Node

@export var chunk_manager: ChunkManager
@export var tick_interval: float = 0.6
@export var max_updates_per_tick: int = 32


const HORIZONTAL_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

const DOWN_OFFSET: Vector3i = Vector3i(0, -1, 0)

const ALL_NEIGHBOR_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var _queued_positions: Array[Vector3i] = []
var _queued_flags: Dictionary[Vector3i, bool] = {}

var _tick_timer: float = 0.0

var _thread: Thread = null
var _thread_mutex: Mutex = Mutex.new()
var _thread_result: Dictionary[Vector3i, Array] = {}
var _thread_busy: bool = false
var _task_id: int = -1


func _process(delta: float) -> void:
	if chunk_manager == null:
		return
	
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_run_tick()
	
	_collect_thread_result()


func enqueue(world_voxel_position: Vector3i) -> void:
	if _queued_flags.has(world_voxel_position):
		return
	
	_queued_flags[world_voxel_position] = true
	_queued_positions.append(world_voxel_position)


func wake_neighbors(world_voxel_position: Vector3i) -> void:
	for offset: Vector3i in ALL_NEIGHBOR_OFFSETS:
		var neighbor_position: Vector3i = world_voxel_position + offset
		var neighbor_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(neighbor_position)
		if TerrianData.is_lava(neighbor_type):
			enqueue(neighbor_position)


func _run_tick() -> void:
	if chunk_manager != null and chunk_manager.is_thread_stopping: return
	if _thread_busy:
		return

	var update_count: int = min(max_updates_per_tick, _queued_positions.size())
	if update_count <= 0:
		return

	var positions_to_process: Array[Vector3i] = []
	for i: int in range(update_count):
		var pos: Vector3i = _queued_positions.pop_front()
		_queued_flags.erase(pos)
		positions_to_process.append(pos)

	_thread_busy = true
	_task_id = WorkerThreadPool.add_task(_thread_worker.bind(positions_to_process), false, "water_flow_tick")


func _thread_worker(positions_to_process: Array[Vector3i]) -> void:
	var edits_by_chunk: Dictionary[Vector3i, Array] = {}
	for world_position: Vector3i in positions_to_process:
		if chunk_manager != null and chunk_manager.is_thread_stopping: break
		_process_lava_voxel(world_position, edits_by_chunk)

	_thread_mutex.lock()
	_thread_result = edits_by_chunk
	_thread_mutex.unlock()
	_thread_busy = false


func _collect_thread_result() -> void:
	if _thread_busy or _task_id == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task_id):
		return

	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1

	_thread_mutex.lock()
	var edits_by_chunk: Dictionary = _thread_result
	_thread_result = {}
	_thread_mutex.unlock()

	if edits_by_chunk.is_empty():
		return
	_apply_edits(edits_by_chunk)


func _process_lava_voxel(world_position: Vector3i, edits_by_chunk: Dictionary[Vector3i, Array]) -> void:
	var voxel_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(world_position)
	if not TerrianData.is_lava(voxel_type):
		return
	
	var current_level: int = TerrianData.get_lava_level(voxel_type)
	if current_level < 0:
		return
	
	var below_position: Vector3i = world_position + DOWN_OFFSET
	var below_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(below_position)
	
	if below_type == TerrianData.TerrianType.AIR:
		_queue_write(below_position, TerrianData.lava_type_for_level(0), edits_by_chunk)
		return
	
	if TerrianData.is_water(below_type):
		_queue_write(below_position, voxel_type, edits_by_chunk)
		return
	
	if current_level >= TerrianData.MAX_LAVA_FLOW_DISTANCE:
		return
	
	var next_level: int = current_level + 1
	var next_type: TerrianData.TerrianType = TerrianData.lava_type_for_level(next_level)
	
	for offset: Vector3i in HORIZONTAL_OFFSETS:
		var neighbor_position: Vector3i = world_position + offset
		var neighbor_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(neighbor_position)
		
		if neighbor_type == TerrianData.TerrianType.AIR:
			_queue_write(neighbor_position, next_type, edits_by_chunk)
		elif TerrianData.is_lava(neighbor_type) and TerrianData.get_lava_level(neighbor_type) > next_level:
			_queue_write(neighbor_position, next_type, edits_by_chunk)
		elif TerrianData.is_water(neighbor_type):
			_queue_write(neighbor_position, next_type, edits_by_chunk)


func _queue_write(world_position: Vector3i, lava_type: TerrianData.TerrianType, edits_by_chunk: Dictionary[Vector3i, Array]) -> void:
	var chunk_world_key: Vector3i = chunk_manager.voxel_to_chunk_key(world_position)
	
	if not edits_by_chunk.has(chunk_world_key):
		edits_by_chunk[chunk_world_key] = []
	
	var local_position: Vector3i = world_position - chunk_world_key
	
	edits_by_chunk[chunk_world_key].append({
		"pos": local_position,
		"type": lava_type
	})
	
	enqueue(world_position)


func _apply_edits(edits_by_chunk: Dictionary[Vector3i, Array]) -> void:
	for chunk_world_key: Vector3i in edits_by_chunk.keys():	# MUST run on main thread
		var chunk: Chunk = chunk_manager.get_loaded_chunk(chunk_world_key)
		if chunk == null:
			continue
		
		chunk.apply_lava_voxel_edits(edits_by_chunk[chunk_world_key])


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
