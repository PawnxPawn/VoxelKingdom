class_name ChunkManager
extends Node

signal first_chunk_ready

# Singleton instance (optional, matches your original intent)
var instance: ChunkManager

# ==========================
# World / generation settings
# ==========================

# Total world size in voxels (X, Y, Z). This is the finite world box.
@export var world_dimensions: Vector3i = Vector3i(12800, 64, 12800)

# Default colors for terrain types (passed into Chunk).
@export var terrain_colors: Dictionary[TerrianData.TerrianType, Color]

# Size of each chunk in voxels per axis (X, Y, Z).
@export var chunk_size: int = 16

@export var noise_frequency: float = 0.003
@export var noise_seed: int = 0

# How many chunk generation tasks are dispatched per frame.
@export var dispatch_chunks_per_frame: int = 12

# How many completed chunks are added to the scene tree per frame.
@export var add_chunks_per_frame: int = 12

# Radius (in chunk grid units) around the player where chunks are considered for loading.
@export var view_distance_in_chunks: int = 4

# Extra distance beyond view_distance before chunks are unloaded (ahead of player).
@export var unload_buffer_in_chunks: int = 4

@export_group("Directional Streaming")
# Inner radius around the player that is always kept loaded, regardless of direction.
@export var core_radius_in_chunks: int = 2

# Soft forward cone: only chunks whose direction from the player has dot >= this
# are considered "ahead". 0.5 = 60° cone.
@export var forward_dot_threshold: float = 0.5

# If the player's movement direction changes more than this dot threshold,
# the load queue is cleared so new forward chunks get priority.
@export var direction_change_dot_threshold: float = 0.3

# How far beyond core_radius a non-forward (behind) chunk survives before being unloaded.
@export var behind_unload_buffer_in_chunks: int = 2

@onready var seed_label: Label = %SeedLabel

# ==========================
# Noise / generation helpers
# ==========================

var terrain_noise: FastNoiseLite = FastNoiseLite.new()
# Number of chunks in each axis, computed from world_dimensions and chunk_size.
var number_of_chunks: Vector3i

# Chunk scene.
var chunk_scene: PackedScene = preload("uid://vqyykbxy7a60")

# ==========================
# Chunk storage / threading
# ==========================

# Maps world-space chunk keys (multiples of chunk_size) to Chunk instances.
var chunks_by_key: Dictionary[Vector3i, Chunk] = {}

var chunks_mutex: Mutex = Mutex.new()

# Chunks that finished generating and are waiting to be added to the scene tree.
var pending_chunks_to_add: Array[Chunk] = []

var pending_chunks_mutex: Mutex = Mutex.new()

var total_voxel_count: int = 0
var start_time_usec: float = 0.0
var is_first_chunk_added: bool = false

# ==========================
# Streaming / movement state
# ==========================

# Player node
var stream_target: Node3D = null

# Keys currently being generated (to avoid duplicate tasks).
var loading_chunks_flags: Dictionary[Vector3i, bool] = {}

var loading_chunks_mutex: Mutex = Mutex.new()

# Ordered list of chunk keys to be generated.
var load_queue: Array[Vector3i] = []

# WorkerThreadPool task IDs for chunk generation.
var active_task_ids: Array[int] = []

# Last chunk grid coordinate used as streaming center.
var last_center_chunk_coord: Vector3i = Vector3i(1 << 30, 0, 1 << 30)

var last_stream_world_position: Vector3 = Vector3.ZERO
var has_last_stream_position: bool = false

# Normalized movement direction in XZ plane.
var movement_direction_xz: Vector2 = Vector2.RIGHT

# Chunks that have been modified
var modified_chunks: Dictionary[Vector3i, PackedInt32Array] = {}


# ==========================
# Lifecycle
# ==========================

func _ready() -> void:
	instance = self
	
	if noise_seed == 0:
		noise_seed = randi()
	
	start_time_usec = Time.get_ticks_usec()
	# Configure noise
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_noise.frequency = noise_frequency
	terrain_noise.seed = noise_seed
	
	seed_label.text = "Seed: %s" % noise_seed
	
	# Compute number of chunks in each axis based on world_dimensions and chunk_size.
	number_of_chunks = Vector3i(
		ceili(float(world_dimensions.x) / float(chunk_size)),
		ceili(float(world_dimensions.y) / float(chunk_size)),
		ceili(float(world_dimensions.z) / float(chunk_size))
	)
	
	_update_streaming()


func _process(_delta: float) -> void:
	# Find the player as streaming target. (I'm being lazy about it!)
	if stream_target == null:
		stream_target = get_tree().get_first_node_in_group("player")
		
	# Add any finished chunks to the scene tree.
	_flush_pending_chunks()
	_update_movement_direction()
	# Update which chunks should be loaded/unloaded.
	_update_streaming()
	# Dispatch chunk generation tasks from the load queue.
	_dispatch_load_queue()
	
# ==========================
# Pending chunk addition
# ==========================

func _flush_pending_chunks() -> void:
	var chunks_to_add: Array[Chunk] = []
	
	pending_chunks_mutex.lock()
	var count: int = min(add_chunks_per_frame, pending_chunks_to_add.size())
	for i: int in range(count):
		var chunk: Chunk = pending_chunks_to_add.pop_front()
		if is_instance_valid(chunk):
			chunks_to_add.append(chunk)
	pending_chunks_mutex.unlock()
	
	for chunk: Chunk in chunks_to_add:
		add_child(chunk)
		
		if not is_first_chunk_added:
			is_first_chunk_added = true
			first_chunk_ready.emit()

# ==========================
# Coordinate helpers
# ==========================

# Returns chunk grid coordinat (Chunk Spac).
func _world_to_chunk_grid_coord(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_position.x / float(chunk_size)),
		0,
		floori(world_position.z / float(chunk_size))
	)


# Converts chunk grid coordinate to world-space.
func _chunk_grid_to_world_key(grid_coord: Vector3i) -> Vector3i:
	return Vector3i(
		grid_coord.x * chunk_size,
		grid_coord.y * chunk_size,
		grid_coord.z * chunk_size
	)

# ==========================
# Movement direction tracking
# ==========================

func _update_movement_direction() -> void:
	if stream_target == null:
		return
	
	var current_position: Vector3 = stream_target.global_position
	
	if not has_last_stream_position:
		last_stream_world_position = current_position
		has_last_stream_position = true
		return
	
	var delta_xz: Vector2 = Vector2(
		current_position.x - last_stream_world_position.x,
		current_position.z - last_stream_world_position.z
	)
	last_stream_world_position = current_position
	
	# Ignore extremely small movement to avoid jitter.
	if delta_xz.length() < 0.01:
		return
		
	var new_direction: Vector2 = delta_xz.normalized()
	
	# If the movement direction changes significantly (dot < threshold),
	# clear the load queue so new forward chunks get priority.
	if movement_direction_xz.dot(new_direction) < direction_change_dot_threshold:
		load_queue.clear()
		
	movement_direction_xz = new_direction

# ==========================
# Streaming update
# ==========================

func _update_streaming() -> void:
	var center_world_position: Vector3 = stream_target.global_position if stream_target != null else Vector3.ZERO
	var center_chunk_grid: Vector3i = _world_to_chunk_grid_coord(center_world_position)
	
	if center_chunk_grid == last_center_chunk_coord:
		return
		
	last_center_chunk_coord = center_chunk_grid
	
	_queue_needed_chunks(center_chunk_grid)
	_unload_distant_chunks(center_chunk_grid)

# ==========================
# Forward cone helper
# ==========================

func _is_chunk_ahead(offset_grid_2d: Vector2i) -> bool:
	# offset_grid_2d is the chunk grid offset from the center (X,Z).
	# We treat this as a direction vector and compare with movement_direction_xz.
	if offset_grid_2d == Vector2i.ZERO:
		return true
	
	var offset_direction: Vector2 = Vector2(offset_grid_2d.x, offset_grid_2d.y).normalized()
	var alignment: float = offset_direction.dot(movement_direction_xz)
	
	# Chunks with alignment >= forward_dot_threshold are considered "ahead".
	return alignment >= forward_dot_threshold

# ==========================
# Queueing chunks to load
# ==========================

func _queue_needed_chunks(center_chunk_grid: Vector3i) -> void:
	var needed_chunk_keys: Array[Vector3i] = []
	
	# Iterate over chunk grid coordinates in a square around the center.
	for grid_x: int in range(center_chunk_grid.x - view_distance_in_chunks, center_chunk_grid.x + view_distance_in_chunks + 1):
		for grid_z: int in range(center_chunk_grid.z - view_distance_in_chunks, center_chunk_grid.z + view_distance_in_chunks + 1):
			var offset_grid_2d: Vector2i = Vector2i(grid_x - center_chunk_grid.x, grid_z - center_chunk_grid.z)
			var distance_in_chunks: int = maxi(absi(offset_grid_2d.x), absi(offset_grid_2d.y))
			
			# Skip outside view distance.
			if distance_in_chunks > view_distance_in_chunks:
				continue
			
			# Clamp to finite world bounds in chunk grid space.
			if grid_x < 0 or grid_x >= number_of_chunks.x:
				continue
			if grid_z < 0 or grid_z >= number_of_chunks.z:
				continue
			
			# Forward cone:
			# - Always allow chunks inside core radius.
			# - Outside core radius, only allow chunks that are "ahead".
			if distance_in_chunks > core_radius_in_chunks and not _is_chunk_ahead(offset_grid_2d):
				continue
				
			# For each vertical chunk layer (Y), within world bounds.
			for grid_y: int in range(number_of_chunks.y):
				var chunk_grid_coord: Vector3i = Vector3i(grid_x, grid_y, grid_z)
				var chunk_world_key: Vector3i = _chunk_grid_to_world_key(chunk_grid_coord)
				
				# Check if chunk is already loaded.
				chunks_mutex.lock()
				var already_loaded: bool = chunks_by_key.has(chunk_world_key)
				chunks_mutex.unlock()
				
				if already_loaded:
					continue
					
				# Check if chunk is already being generated.
				loading_chunks_mutex.lock()
				var already_loading: bool = loading_chunks_flags.has(chunk_world_key)
				loading_chunks_mutex.unlock()
				
				if already_loading:
					continue
					
				# Check if chunk is already in the load queue.
				if chunk_world_key in load_queue:
					continue
					
				needed_chunk_keys.append(chunk_world_key)
				
	if needed_chunk_keys.is_empty():
		return
		
	# Append all needed chunk keys to the load queue.
	load_queue.append_array(needed_chunk_keys)
	
	var center_world_x: int = center_chunk_grid.x * chunk_size
	var center_world_z: int = center_chunk_grid.z * chunk_size
	var move_dir: Vector2 = movement_direction_xz
	
	# Sort load_queue:
	# 1 Core radius chunks first.
	# 2 Chunks most aligned with movement direction.
	# 3 Then closest in world-space.
	load_queue.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var a_grid: Vector2i = Vector2i(int(a.x / float(chunk_size)) - center_chunk_grid.x, int(a.z / float(chunk_size)) - center_chunk_grid.z)
		var b_grid: Vector2i = Vector2i(int(b.x / float(chunk_size)) - center_chunk_grid.x, int(b.z / float(chunk_size)) - center_chunk_grid.z)
		
		var a_dist: int = maxi(absi(a_grid.x), absi(a_grid.y))
		var b_dist: int = maxi(absi(b_grid.x), absi(b_grid.y))
		
		var a_is_core: bool = a_dist <= core_radius_in_chunks
		var b_is_core: bool = b_dist <= core_radius_in_chunks
		
		if a_is_core != b_is_core:
			return a_is_core
			
		var a_align: float = Vector2(a_grid.x, a_grid.y).normalized().dot(move_dir) if a_grid != Vector2i.ZERO else 1.0
		var b_align: float = Vector2(b_grid.x, b_grid.y).normalized().dot(move_dir) if b_grid != Vector2i.ZERO else 1.0
		
		if not is_equal_approx(a_align, b_align):
			return a_align > b_align
			
		var a_sq: int = (a.x - center_world_x) * (a.x - center_world_x) + (a.z - center_world_z) * (a.z - center_world_z)
		var b_sq: int = (b.x - center_world_x) * (b.x - center_world_x) + (b.z - center_world_z) * (b.z - center_world_z)
		return a_sq < b_sq
	)

# ==========================
# Dispatching chunk generation
# ==========================

func _dispatch_load_queue() -> void:
	var count: int = min(dispatch_chunks_per_frame, load_queue.size())
	for i: int in range(count):
		var chunk_world_key: Vector3i = load_queue.pop_front()
		
		loading_chunks_mutex.lock()
		loading_chunks_flags[chunk_world_key] = true
		loading_chunks_mutex.unlock()
		
		# Convert world key to chunk grid coord for generation.
		var grid_coord: Vector3i = Vector3i(
			int(chunk_world_key.x / float(chunk_size)),
			int(chunk_world_key.y / float(chunk_size)),
			int(chunk_world_key.z / float(chunk_size))
		)
		
		var task_id: int = WorkerThreadPool.add_task(_generate_chunk_at.bind(grid_coord), false, "chunk_generation")
		active_task_ids.append(task_id)

# ==========================
# Unloading distant chunks
# ==========================

func _unload_distant_chunks(center_chunk_grid: Vector3i) -> void:
	var ahead_unload_distance_in_chunks: int = view_distance_in_chunks + unload_buffer_in_chunks
	var behind_unload_distance_in_chunks: int = core_radius_in_chunks + behind_unload_buffer_in_chunks
	
	chunks_mutex.lock()
	var keys: Array = chunks_by_key.keys()
	chunks_mutex.unlock()
	
	for key in keys:
		var grid_x: int = key.x / chunk_size
		var grid_z: int = key.z / chunk_size
		var offset_grid_2d: Vector2i = Vector2i(grid_x - center_chunk_grid.x, grid_z - center_chunk_grid.z)
		var distance_in_chunks: int = maxi(absi(offset_grid_2d.x), absi(offset_grid_2d.y))
		
		# Never unload chunks inside core radius.
		if distance_in_chunks <= core_radius_in_chunks:
			continue
			
		# Determine unload distance based on whether chunk is ahead or behind.
		var unload_distance: int = ahead_unload_distance_in_chunks if _is_chunk_ahead(offset_grid_2d) else behind_unload_distance_in_chunks
		
		if distance_in_chunks > unload_distance:
			chunks_mutex.lock()
			var chunk: Chunk = chunks_by_key.get(key)
			var still_pending: bool = chunk != null and not chunk.is_inside_tree()
			if chunk != null and not still_pending:
				chunks_by_key.erase(key)
			chunks_mutex.unlock()
			
			if chunk != null and not still_pending:
				chunk.queue_free()

# ==========================
# Chunk generation (threaded)
# ==========================

func _generate_chunk_at(chunk_grid_coord: Vector3i) -> void:
	var new_chunk: Chunk = chunk_scene.instantiate() as Chunk
	
	# World-space position is chunk_grid_coord * chunk_size.
	new_chunk.position = Vector3(
		chunk_grid_coord.x,
		chunk_grid_coord.y,
		chunk_grid_coord.z
	) * float(chunk_size)
	
	# Generate voxel data and mesh.
	new_chunk.generate_date(chunk_size, world_dimensions.y, terrain_noise, terrain_colors)
	var chunk_world_key: Vector3i = Vector3i(new_chunk.position)
	if modified_chunks.has(chunk_world_key):
		var saved_voxels: PackedInt32Array = modified_chunks[chunk_world_key]
		new_chunk.chunk_data.voxels = saved_voxels
		new_chunk.chunk_data.voxel_amount = _count_non_air(saved_voxels)
	new_chunk.generate_mesh()
	new_chunk.compute_collision_boxes()
	
	# Store chunk in dictionary.
	chunks_mutex.lock()
	chunks_by_key[chunk_world_key] = new_chunk
	chunks_mutex.unlock()
	
	# Queue chunk for scene tree.
	pending_chunks_mutex.lock()
	pending_chunks_to_add.append(new_chunk)
	pending_chunks_mutex.unlock()
	
	# Mark chunk as no longer loading.
	loading_chunks_mutex.lock()
	loading_chunks_flags.erase(chunk_world_key)
	loading_chunks_mutex.unlock()

# ==========================
# Voxel editing helpers
# ==========================

func add_voxel_at_hit(hit_position: Vector3, hit_normal: Vector3, voxel_type: TerrianData.TerrianType) -> void:
	# Sample slightly inside the target surface to avoid precision issues.
	var sample_world_position: Vector3 = hit_position + hit_normal * 0.01
	var chunk_world_key: Vector3i = _world_to_chunk_key(sample_world_position)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return
		
	var local_voxel_position: Vector3i = _world_to_local_voxel_centered(sample_world_position, chunk_world_key)
	chunk.set_voxel(local_voxel_position, voxel_type)
	_store_modified_chunk(chunk_world_key, chunk)


func remove_voxel_at_hit(hit_position: Vector3, hit_normal: Vector3) -> void:
	# Sample slightly inside the block being removed.
	var sample_world_position: Vector3 = hit_position - hit_normal * 0.01
	var chunk_world_key: Vector3i = _world_to_chunk_key(sample_world_position)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return
		
	var local_voxel_position: Vector3i = _world_to_local_voxel_centered(sample_world_position, chunk_world_key)
	chunk.remove_voxel_at_local(local_voxel_position)
	_store_modified_chunk(chunk_world_key, chunk)


# ==========================
# World/local conversion
# ==========================

func _world_to_chunk_key(world_position: Vector3) -> Vector3i:
	# Returns world-space chunk key (multiples of chunk_size) for a given world position.
	return Vector3i(
		floori((world_position.x + 0.5) / float(chunk_size)) * chunk_size,
		floori((world_position.y + 0.5) / float(chunk_size)) * chunk_size,
		floori((world_position.z + 0.5) / float(chunk_size)) * chunk_size
	)


func _world_to_local_voxel_centered(world_position: Vector3, chunk_world_key: Vector3i) -> Vector3i:
	# Converts world position to local voxel coordinates inside the chunk.
	return Vector3i(
		roundi(world_position.x) - chunk_world_key.x,
		roundi(world_position.y) - chunk_world_key.y,
		roundi(world_position.z) - chunk_world_key.z
	)

# ==========================
# Spawn height / column checks
# ==========================

func get_highest_voxel_at_xz(world_x: float, world_z: float) -> float:
	var base_chunk_world_key: Vector3i = _world_to_chunk_key(Vector3(world_x, 0.0, world_z))
	var highest_world_y: float = -INF
	
	for y_chunk_index: int in range(number_of_chunks.y):
		var chunk_world_key: Vector3i = Vector3i(
			base_chunk_world_key.x,
			y_chunk_index * chunk_size,
			base_chunk_world_key.z
		)
		
		chunks_mutex.lock()
		var chunk: Chunk = chunks_by_key.get(chunk_world_key)
		chunks_mutex.unlock()
		
		if chunk == null:
			continue
			
		var local_x: int = roundi(world_x) - chunk_world_key.x
		var local_z: int = roundi(world_z) - chunk_world_key.z
		
		for local_y: int in range(chunk_size - 1, -1, -1):
			var voxel_type: TerrianData.TerrianType = chunk.chunk_data.get_voxel(Vector3i(local_x, local_y, local_z))
			if voxel_type != TerrianData.TerrianType.AIR:
				var world_y: float = float(chunk_world_key.y) + float(local_y)
				if world_y > highest_world_y:
					highest_world_y = world_y
				break
				
	if highest_world_y == -INF:
		return 0.0
		
	return highest_world_y


func get_spawn_height(world_x: float, world_z: float) -> int:
	var voxel_y: int = int(get_highest_voxel_at_xz(world_x, world_z))
	return voxel_y


func is_chunk_loaded_at(world_position: Vector3) -> bool:
	var chunk_world_key: Vector3i = _world_to_chunk_key(world_position)
	
	chunks_mutex.lock()
	var loaded: bool = chunks_by_key.has(chunk_world_key)
	chunks_mutex.unlock()
	
	return loaded


func is_column_loaded_at(world_x: float, world_z: float) -> bool:
	var base_chunk_world_key: Vector3i = _world_to_chunk_key(Vector3(world_x, 0.0, world_z))
	
	chunks_mutex.lock()
	for y_chunk_index: int in range(number_of_chunks.y):
		var chunk_world_key: Vector3i = Vector3i(
			base_chunk_world_key.x,
			y_chunk_index * chunk_size,
			base_chunk_world_key.z
		)
		if not chunks_by_key.has(chunk_world_key):
			chunks_mutex.unlock()
			return false
	chunks_mutex.unlock()
	
	return true

# ==========================
# Cleanup
# ==========================

func _exit_tree() -> void:
	for id: int in active_task_ids:
		WorkerThreadPool.wait_for_task_completion(id)

# ==========================
# Modified Chunk
# ==========================

func _store_modified_chunk(chunk_world_key: Vector3i, chunk: Chunk) -> void:
	modified_chunks[chunk_world_key] = chunk.chunk_data.get_voxels_copy()

# =========================
# Other Helpers
# =========================

func _count_non_air(voxels: PackedInt32Array) -> int:
	var count := 0
	for v in voxels:
		if v != TerrianData.TerrianType.AIR:
			count += 1
	return count

# ==========================
# Player signals
# ==========================

func _on_player_add_block(hit_position: Vector3, hit_normal: Vector3, terrain_type: TerrianData.TerrianType) -> void:
	add_voxel_at_hit(hit_position, hit_normal, terrain_type)


func _on_player_remove_block(hit_position: Vector3, hit_normal: Vector3) -> void:
	remove_voxel_at_hit(hit_position, hit_normal)
