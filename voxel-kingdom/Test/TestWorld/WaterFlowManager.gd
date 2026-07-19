#-###########################################
# WaterFlowManager (Threaded)
#-###########################################

class_name WaterFlowManager
extends Node

@export var chunk_manager: ChunkManager
@export var tick_interval: float = 0.2
@export var max_updates_per_tick: int = 96

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
var _thread_result: Dictionary = {}
var _thread_busy: bool = false


#----------------
# Process
#----------------
func _process(delta: float) -> void:
	if chunk_manager == null:
		return
		
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_run_tick()
	
	_collect_thread_result()


#-###########################################
# Public API
#-###########################################

func enqueue(world_voxel_position: Vector3i) -> void:
	if _queued_flags.has(world_voxel_position):
		return
		
	_queued_flags[world_voxel_position] = true
	_queued_positions.append(world_voxel_position)


func wake_neighbors(world_voxel_position: Vector3i) -> void:
	for offset: Vector3i in ALL_NEIGHBOR_OFFSETS:
		var neighbor_position: Vector3i = world_voxel_position + offset
		if TerrianData.is_water(chunk_manager.get_voxel_type_at(neighbor_position)):
			enqueue(neighbor_position)


#-###########################################
# Tick Dispatch (Thread-per-tick)
#-###########################################

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
	
	# Create a NEW thread every tick
	_thread = Thread.new()
	_thread.start(_thread_worker.bind(positions_to_process))


#-###########################################
# Thread Worker
#-###########################################

func _thread_worker(positions_to_process: Array[Vector3i]) -> void:
	var edits_by_chunk: Dictionary[Vector3i, Array] = {}
	
	
	for world_position: Vector3i in positions_to_process:
		if chunk_manager != null and chunk_manager.is_thread_stopping: break
		_process_water_voxel(world_position, edits_by_chunk)
	
	_thread_mutex.lock()
	_thread_result = edits_by_chunk
	_thread_mutex.unlock()
	
	_thread_busy = false


#----------------
# Water Logic (Pure Data)
#----------------
func _process_water_voxel(world_position: Vector3i, edits_by_chunk: Dictionary[Vector3i, Array]) -> void:
	var voxel_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(world_position)
	if not TerrianData.is_water(voxel_type):
		return
		
	var current_level: int = TerrianData.get_water_level(voxel_type)
	
	var below_position: Vector3i = world_position + DOWN_OFFSET
	if chunk_manager.get_voxel_type_at(below_position) == TerrianData.TerrianType.AIR:
		_queue_write(below_position, TerrianData.water_type_for_level(0), edits_by_chunk)
		return
		
	if current_level >= TerrianData.MAX_WATER_FLOW_DISTANCE:
		return
		
	var next_level: int = current_level + 1
	var next_type: TerrianData.TerrianType = TerrianData.water_type_for_level(next_level)
	
	for offset: Vector3i in HORIZONTAL_OFFSETS:
		var neighbor_position: Vector3i = world_position + offset
		var neighbor_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(neighbor_position)
		
		if neighbor_type == TerrianData.TerrianType.AIR:
			_queue_write(neighbor_position, next_type, edits_by_chunk)
		elif TerrianData.is_water(neighbor_type) and TerrianData.get_water_level(neighbor_type) > next_level:
			_queue_write(neighbor_position, next_type, edits_by_chunk)


#----------------
# Queue Write
#----------------
func _queue_write(world_position: Vector3i, water_type: TerrianData.TerrianType, edits_by_chunk: Dictionary[Vector3i, Array]) -> void:
	var chunk_world_key: Vector3i = chunk_manager.voxel_to_chunk_key(world_position)
	
	if not edits_by_chunk.has(chunk_world_key):
		edits_by_chunk[chunk_world_key] = []
		
	var local_position: Vector3i = world_position - chunk_world_key
	
	edits_by_chunk[chunk_world_key].append({
		"pos": local_position,
		"type": water_type
	})
	
	enqueue(world_position)


#-###########################################
# Collect Thread Results
#-###########################################

func _collect_thread_result() -> void:
	if _thread_busy:
		return
		
	if _thread == null:
		return
		
	if _thread.is_alive():
		return
		
	_thread_mutex.lock()
	var edits_by_chunk: Dictionary = _thread_result
	_thread_result = {}
	_thread_mutex.unlock()
	
	_thread.wait_to_finish()
	_thread = null
	
	if edits_by_chunk.is_empty():
		return
		
	_apply_edits(edits_by_chunk)


#----------------
# Apply Edits (Main Thread)
#----------------
func _apply_edits(edits_by_chunk: Dictionary) -> void:
	for chunk_world_key: Vector3i in edits_by_chunk.keys():
		var chunk: Chunk = chunk_manager.get_loaded_chunk(chunk_world_key)
		if chunk == null:
			continue
		
		chunk.apply_water_voxel_edits(edits_by_chunk[chunk_world_key])


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
