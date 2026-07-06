class_name ChunkManager extends Node

signal first_chunk_ready

var instance: ChunkManager
@export var dimensions: Vector3i = Vector3i(128, 64, 128)
@export var colors: Dictionary[TerrianData.TerrianType, Color]
@export var chunk_size: int = 32
@export var noise_frequency: float = 0.003
@export var noise_seed: int = randi()
@export var chunks_per_frame: int = 2
@onready var seed_label: Label = %SeedLabel
var noise = FastNoiseLite.new()
var number_of_chunks: Vector3i
var chunk_scene: PackedScene = preload("uid://vqyykbxy7a60")
var chunks: Dictionary[Vector3i, Chunk] = {}
var chunks_mutex: Mutex = Mutex.new()
var pending_chunks: Array[Chunk] = []
var pending_mutex: Mutex = Mutex.new()
var chunk_coords: Array[Vector3i] = []
var task_id: int = -1
var cubes: int = 0
var _start_time: float = 0.0
var is_first_chunk_added: bool = false


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
	
	for x in range(number_of_chunks.x):
		for y in range(number_of_chunks.y):
			for z in range(number_of_chunks.z):
				chunk_coords.append(Vector3i(x, y, z))
	
	var worker_count: int = max(1, OS.get_processor_count() / 2.0)
	task_id = WorkerThreadPool.add_group_task(_generate_chunk_by_index, chunk_coords.size(), worker_count, false, "chunk_generation")

func _process(_delta: float) -> void:
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


func _generate_chunk_by_index(index: int) -> void:
	var coord: Vector3i = chunk_coords[index]
	
	var new_chunk: Chunk = chunk_scene.instantiate()
	new_chunk.position = Vector3(coord.x, coord.y, coord.z) * chunk_size
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
		floori(world_position.x / chunk_size) * chunk_size,
		floori(world_position.y / chunk_size) * chunk_size,
		floori(world_position.z / chunk_size) * chunk_size
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
	var voxel_y =  int(get_highest_voxel_at_xz(x, z))
	print(voxel_y)
	return voxel_y



func _exit_tree() -> void:
	if task_id != -1:
		WorkerThreadPool.wait_for_group_task_completion(task_id)


func _on_player_add_block(hit_position: Vector3, hit_normal: Vector3, terrian: TerrianData.TerrianType) -> void:
	add_voxel_at_hit(hit_position, hit_normal, terrian)


func _on_player_remove_block(hit_position: Vector3, hit_normal: Vector3) -> void:
	remove_voxel_at_hit(hit_position, hit_normal)
