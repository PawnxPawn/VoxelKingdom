class_name ChunkManager extends Node

signal first_chunk_ready

var instance: ChunkManager
@export var dimensions: Vector3i = Vector3i(128, 64, 128)
@export var colors: Dictionary[TerrianData.TerrianType, Color]
@export var chunk_size: int = 32
@export var noise_frequency: float = 0.003
@export var noise_seed: int = randi()

@export var chunks_per_frame: int = 12
@export var view_distance: int = 10
@export var unload_buffer: int = 4

@onready var seed_label: Label = %SeedLabel
var noise = FastNoiseLite.new()
var number_of_chunks: Vector3i
var chunk_scene: PackedScene = preload("uid://vqyykbxy7a60")
var chunks: Dictionary[Vector3i, Chunk] = {}
var chunks_mutex: Mutex = Mutex.new()
var pending_chunks: Array[Chunk] = []
var pending_mutex: Mutex = Mutex.new()
var cubes: int = 0
var _start_time: float = 0.0
var is_first_chunk_added: bool = false

var stream_target: Node3D = null

var loading_chunks: Dictionary[Vector3i, bool] = {}
var loading_mutex: Mutex = Mutex.new()
var load_queue: Array[Vector3i] = []
var active_tasks: Array[int] = []
var _last_center_coord: Vector3i = Vector3i(1 << 30, 0, 1 << 30)


func _ready() -> void:
	instance = self
	
	_start_time = Time.get_ticks_usec()
	
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.seed = noise_seed
	
	seed_label.text = "Seed: %s" % noise_seed
	
	number_of_chunks = Vector3i(
		ceili(float(dimensions.x) / chunk_size),
		ceili(float(dimensions.y) / chunk_size),
		ceili(float(dimensions.z) / chunk_size)
	)
	
	_update_streaming()


func _process(_delta: float) -> void:
	if stream_target == null:
		stream_target = get_tree().get_first_node_in_group("player")
	
	_flush_pending_chunks()
	_update_streaming()
	_dispatch_load_queue()


func _flush_pending_chunks() -> void:
	var to_add: Array[Chunk] = []
	
	pending_mutex.lock()
	var count: int = min(chunks_per_frame, pending_chunks.size())
	for i in range(count):
		to_add.append(pending_chunks.pop_front())
	pending_mutex.unlock()
	
	for chunk in to_add:
		add_child(chunk)
		
		if not is_first_chunk_added:
			is_first_chunk_added = true
			first_chunk_ready.emit()


func _get_grid_coord(world_pos: Vector3) -> Vector3i:
	return Vector3i(floori(world_pos.x / chunk_size), 0, floori(world_pos.z / chunk_size))


func _update_streaming() -> void:
	var center_world: Vector3 = stream_target.global_position if stream_target != null else Vector3.ZERO
	var center: Vector3i = _get_grid_coord(center_world)
	
	if center == _last_center_coord:
		return
	_last_center_coord = center
	
	_queue_needed_chunks(center)
	_unload_distant_chunks(center)


func _queue_needed_chunks(center: Vector3i) -> void:
	var needed: Array[Vector3i] = []
	
	for x in range(center.x - view_distance, center.x + view_distance + 1):
		for z in range(center.z - view_distance, center.z + view_distance + 1):
			if maxi(absi(x - center.x), absi(z - center.z)) > view_distance:
				continue
			for y in range(number_of_chunks.y):
				var key: Vector3i = Vector3i(x * chunk_size, y * chunk_size, z * chunk_size)
				
				chunks_mutex.lock()
				var already_loaded: bool = chunks.has(key)
				chunks_mutex.unlock()
				
				if already_loaded:
					continue
					
				loading_mutex.lock()
				var already_loading: bool = loading_chunks.has(key)
				loading_mutex.unlock()
				
				if already_loading:
					continue
					
				if key in load_queue:
					continue
					
				needed.append(key)
				
	if needed.is_empty():
		return
		
	load_queue.append_array(needed)
	
	var center_key_value: Vector3i = center_key(center)
	load_queue.sort_custom(func(a, b):
		return a.distance_squared_to(center_key_value) < b.distance_squared_to(center_key_value)
	)


func center_key(center: Vector3i) -> Vector3i:
	return Vector3i(center.x * chunk_size, 0, center.z * chunk_size)


func _dispatch_load_queue() -> void:
	var count: int = min(chunks_per_frame, load_queue.size())
	for i in range(count):
		var key: Vector3i = load_queue.pop_front()
		
		loading_mutex.lock()
		loading_chunks[key] = true
		loading_mutex.unlock()
		
		var grid_coord: Vector3i = Vector3i(int(key.x / float(chunk_size)), int(key.y / float(chunk_size)), int(key.z / float(chunk_size)))
		var task_id: int = WorkerThreadPool.add_task(_generate_chunk_at.bind(grid_coord), false, "chunk_generation")
		active_tasks.append(task_id)


func _unload_distant_chunks(center: Vector3i) -> void:
	var unload_dist: int = view_distance + unload_buffer
	
	chunks_mutex.lock()
	var keys: Array = chunks.keys()
	chunks_mutex.unlock()
	
	for key in keys:
		var grid_x: int = key.x / chunk_size
		var grid_z: int = key.z / chunk_size
		var dist: int = maxi(absi(grid_x - center.x), absi(grid_z - center.z))
		
		if dist > unload_dist:
			chunks_mutex.lock()
			var chunk: Chunk = chunks.get(key)
			if chunk != null:
				chunks.erase(key)
			chunks_mutex.unlock()
			
			if chunk != null:
				chunk.queue_free()


func _generate_chunk_at(grid_coord: Vector3i) -> void:
	var new_chunk: Chunk = chunk_scene.instantiate()
	new_chunk.position = Vector3(grid_coord.x, grid_coord.y, grid_coord.z) * chunk_size
	new_chunk.generate_date(chunk_size, dimensions.y, noise, colors)
	new_chunk.generate_mesh()
	new_chunk.compute_collision_boxes()
	
	var key: Vector3i = Vector3i(new_chunk.position)
	
	chunks_mutex.lock()
	chunks[key] = new_chunk
	chunks_mutex.unlock()
	
	pending_mutex.lock()
	pending_chunks.append(new_chunk)
	pending_mutex.unlock()
	
	loading_mutex.lock()
	loading_chunks.erase(key)
	loading_mutex.unlock()


func add_voxel_at_hit(hit_position: Vector3, hit_normal: Vector3, voxel: TerrianData.TerrianType) -> void:
	var sample: Vector3 = hit_position + hit_normal * 0.01
	var chunk_key: Vector3i = _world_to_chunk_key(sample)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks.get(chunk_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return
		
	var local_pos: Vector3i = _world_to_local_voxel_centered(sample, chunk_key)
	chunk.set_voxel(local_pos, voxel)


func remove_voxel_at_hit(hit_position: Vector3, hit_normal: Vector3) -> void:
	var sample: Vector3 = hit_position - hit_normal * 0.01
	var chunk_key: Vector3i = _world_to_chunk_key(sample)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks.get(chunk_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return
		
	var local_pos: Vector3i = _world_to_local_voxel_centered(sample, chunk_key)
	chunk.remove_voxel_at_local(local_pos)


func _world_to_chunk_key(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori((world_position.x + 0.5) / chunk_size) * chunk_size,
		floori((world_position.y + 0.5) / chunk_size) * chunk_size,
		floori((world_position.z + 0.5) / chunk_size) * chunk_size
	)


func _world_to_local_voxel_centered(world_position: Vector3, chunk_key: Vector3i) -> Vector3i:
	return Vector3i(
		roundi(world_position.x) - chunk_key.x,
		roundi(world_position.y) - chunk_key.y,
		roundi(world_position.z) - chunk_key.z)


func get_highest_voxel_at_xz(world_x: float, world_z: float) -> float:
	var base_key := _world_to_chunk_key(Vector3(world_x, 0, world_z))
	var highest_world_y := -INF

	for y_chunk in range(number_of_chunks.y):
		var chunk_key := Vector3i(base_key.x, y_chunk * chunk_size, base_key.z)
		
		chunks_mutex.lock()
		var chunk: Chunk = chunks.get(chunk_key)
		chunks_mutex.unlock()
		
		if chunk == null:
			continue
			
		var local_x := roundi(world_x) - chunk_key.x
		var local_z := roundi(world_z) - chunk_key.z
		
		for local_y in range(chunk_size - 1, -1, -1):
			var voxel: TerrianData.TerrianType = chunk.chunk_data.get_voxel(Vector3i(local_x, local_y, local_z))
			if voxel != TerrianData.TerrianType.AIR:
				var world_y := float(chunk_key.y) + float(local_y)
				if world_y > highest_world_y:
					highest_world_y = world_y
				break
				
	if highest_world_y == -INF:
		return 0
		
	return highest_world_y


func get_spawn_height(x: float, z: float) -> int:
	var voxel_y = int(get_highest_voxel_at_xz(x, z))
	print(voxel_y)
	return voxel_y


func is_chunk_loaded_at(world_pos: Vector3) -> bool:
	var chunk_key: Vector3i = _world_to_chunk_key(world_pos)
	
	chunks_mutex.lock()
	var loaded: bool = chunks.has(chunk_key)
	chunks_mutex.unlock()
	
	return loaded


func _exit_tree() -> void:
	for id in active_tasks:
		WorkerThreadPool.wait_for_task_completion(id)


func _on_player_add_block(hit_position: Vector3, hit_normal: Vector3, terrian: TerrianData.TerrianType) -> void:
	add_voxel_at_hit(hit_position, hit_normal, terrian)


func _on_player_remove_block(hit_position: Vector3, hit_normal: Vector3) -> void:
	remove_voxel_at_hit(hit_position, hit_normal)
