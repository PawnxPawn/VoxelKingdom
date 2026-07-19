#-###########################################
# ChunkManager
#-###########################################

class_name ChunkManager
extends Node

signal first_chunk_ready

var instance: ChunkManager

#-###########################################
# World / Generation Settings
#-###########################################

@export var world_dimensions: Vector3i = Vector3i(12800, 736, 12800)
@export var chunk_size: int = 16

@export var noise_frequency: float = 0.01
@export var noise_seed: int = 0

@export var dispatch_chunks_per_frame: int = 20
@export var add_chunks_per_frame: int = 24

@export var view_distance_in_chunks: int = 3
@export var unload_buffer_in_chunks: int = 4

@export_group("Directional Streaming")
@export var core_radius_in_chunks: int = 2
@export var forward_dot_threshold: float = 0.6
@export var direction_change_dot_threshold: float = 0.3
@export var behind_unload_buffer_in_chunks: int = 2

@onready var seed_label: Label = get_node_or_null(^"%SeedLabel")

@export_group("Vertical Streaming")
@export var view_distance_in_chunks_y: int = 1
@export var unload_buffer_in_chunks_y: int = 2

@export_group("Surface Visibility While Flying")
@export var surface_visible_chunks_below: int = 2

var _height_probe: Chunk = null

#-###########################################
# Terrain Generation Settings
#-###########################################

@export_group("Terrain Shape")
@export var terrain_base_height: float = 140.0
@export var terrain_amplitude: float = 60.0
@export_range(0.0, 1.0) var mountain_biome_threshold: float = 0.80

@export_group("Water")
@export var water_level: float = 130.0
@export var water_tick_interval: float = 0.2
@export var water_max_updates_per_tick: int = 96

var water_flow_manager: WaterFlowManager = null

#-###########################################
# Cave Generation Settings
#-###########################################

@export_group("Cave Generation")
@export var cave_frequency: float = 0.03
@export var cave_threshold: float = 0.65
@export var cave_below_surface_min: int = 8
@export var cave_below_surface_max: int = 150

@export_subgroup("Cave Entrances")
@export var cave_entrance_frequency: float = 0.004
@export var cave_entrance_region_threshold: float = 0.72
@export var cave_entrance_surface_reach: int = 6

@export_subgroup("Trees")
@export var tree_frequency: float = 0.02
@export var tree_threshold: float = 0.65
@export var tree_min_spacing: int = 8


var cave_min_y: int = 0
var cave_max_y: int = 0

#-###########################################
# Noise / Generation Helpers
#-###########################################

var terrain_noise: FastNoiseLite = FastNoiseLite.new()
var cave_noise: FastNoiseLite = FastNoiseLite.new()
var cave_entrance_noise: FastNoiseLite = FastNoiseLite.new()
var mountain_biome_noise: FastNoiseLite = FastNoiseLite.new()
var tree_noise: FastNoiseLite = FastNoiseLite.new()

var number_of_chunks: Vector3i
var chunk_scene: PackedScene = preload("uid://vqyykbxy7a60")

#-###########################################
# Chunk Storage / Threading
#-###########################################

var chunks_by_key: Dictionary[Vector3i, Chunk] = {}
var chunks_mutex: Mutex = Mutex.new()

var pending_chunks_to_add: Array[Chunk] = []
var pending_chunks_mutex: Mutex = Mutex.new()

var total_voxel_count: int = 0
var start_time_usec: float = 0.0
var is_first_chunk_added: bool = false

var pending_tree_edits: Dictionary[Vector3i, Array] = {}
var pending_tree_edits_mutex: Mutex = Mutex.new()

var _pending_neighbor_rebuilds: Array[Vector3i] = []
var _pending_neighbor_rebuilds_mutex: Mutex = Mutex.new()

#-###########################################
# Streaming / Movement State
#-###########################################

var stream_target: Node3D = null

var loading_chunks_flags: Dictionary[Vector3i, bool] = {}
var loading_chunks_mutex: Mutex = Mutex.new()

var load_queue: Array[Vector3i] = []
var active_task_ids: Array[int] = []

var last_center_chunk_coord: Vector3i = Vector3i(1 << 30, 0, 1 << 30)

var last_stream_world_position: Vector3 = Vector3.ZERO
var has_last_stream_position: bool = false

var movement_direction_xz: Vector2 = Vector2.RIGHT

var modified_chunks: Dictionary[Vector3i, PackedInt32Array] = {}

var vertical_streaming_locked_to_spawn: bool = true


#-##########################################
# Thread Stopping
#-##########################################

var is_thread_stopping: bool = false

#-##########################################
# Chunk Refresh Per Frame
#-##########################################
var _pending_neighbor_rebuilds_flags: Dictionary[Vector3i, bool] = {}

@export var neighbor_rebuilds_per_frame: int = 4

#-###########################################
# Lifecycle
#-###########################################

func _ready() -> void:
	instance = self
	
	if noise_seed == 0:
		noise_seed = randi()
		
	start_time_usec = Time.get_ticks_usec()
	
	# Hills
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_noise.frequency = noise_frequency
	terrain_noise.seed = noise_seed
	
	# Caves
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise.frequency = cave_frequency
	cave_noise.seed = noise_seed + 1
	
	# Cave Entrances
	cave_entrance_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_entrance_noise.frequency = cave_entrance_frequency
	cave_entrance_noise.seed = noise_seed + 2
	
	# Mountains
	mountain_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	mountain_biome_noise.frequency = 0.0015
	mountain_biome_noise.seed = noise_seed + 50
	
	# Trees
	tree_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	tree_noise.frequency = 0.02
	tree_noise.seed = noise_seed + 100

	if seed_label:
		seed_label.text = "Seed: %s" % noise_seed
	
	number_of_chunks = Vector3i(
		ceili(float(world_dimensions.x) / float(chunk_size)),
		ceili(float(world_dimensions.y) / float(chunk_size)),
		ceili(float(world_dimensions.z) / float(chunk_size))
	)
	
	_height_probe = Chunk.new()
	
	water_flow_manager = WaterFlowManager.new()
	water_flow_manager.chunk_manager = self
	water_flow_manager.tick_interval = water_tick_interval
	water_flow_manager.max_updates_per_tick = water_max_updates_per_tick
	add_child(water_flow_manager)
	
	_update_streaming()

#-###########################################
# Surface Height Estimation (Fly Visibility)
#-###########################################

func _estimate_surface_grid_y(world_x: float, world_z: float) -> int:
	var estimated_height: float = _height_probe.get_final_height(
		world_x,
		world_z,
		terrain_base_height,
		terrain_amplitude,
		terrain_noise,
		mountain_biome_noise,
		_height_probe.mountain_shape_noise,
		_height_probe.steep_noise,
		mountain_biome_threshold
	)
	return clampi(floori(estimated_height / float(chunk_size)), 0, number_of_chunks.y - 1)


func _process(_delta: float) -> void:
	if stream_target == null:
		stream_target = get_tree().get_first_node_in_group("player")
		
	_flush_pending_chunks()
	_flush_pending_neighbor_rebuilds()
	_update_movement_direction()
	_update_streaming()
	_dispatch_load_queue()


#-###########################################
# Pending Chunk Addition
#-###########################################

func _flush_pending_neighbor_rebuilds() -> void:
	_pending_neighbor_rebuilds_mutex.lock()
	var count: int = min(neighbor_rebuilds_per_frame, _pending_neighbor_rebuilds.size())
	var keys_to_process: Array[Vector3i] = []
	for i: int in range(count):
		var key: Vector3i = _pending_neighbor_rebuilds.pop_front()
		_pending_neighbor_rebuilds_flags.erase(key)
		keys_to_process.append(key)
	_pending_neighbor_rebuilds_mutex.unlock()
	
	for key: Vector3i in keys_to_process:
		var chunk: Chunk = get_loaded_chunk(key)
		if chunk != null and chunk.is_inside_tree():
			chunk.request_rebuild()


func _flush_pending_chunks() -> void:
	if is_thread_stopping: return
	var chunks_to_add: Array[Chunk] = []
	
	pending_chunks_mutex.lock()
	var count: int = min(add_chunks_per_frame, pending_chunks_to_add.size())
	for index: int in range(count):
		var chunk: Chunk = pending_chunks_to_add.pop_front()
		if is_instance_valid(chunk):
			chunks_to_add.append(chunk)
	pending_chunks_mutex.unlock()
	
	for chunk: Chunk in chunks_to_add:
		add_child(chunk)
		_refresh_boundaries_on_new_chunk(chunk.chunk_world_origin)
		
		if not is_first_chunk_added:
			is_first_chunk_added = true
			first_chunk_ready.emit()


#-###########################################
# Refresh Neighbors When a New Chunk Spawns
#-###########################################

func _refresh_boundaries_on_new_chunk(new_chunk_world_key: Vector3i) -> void:
	var new_chunk: Chunk = get_loaded_chunk(new_chunk_world_key)
	if new_chunk == null:
		return
		
	var boundary_checks: Array[Dictionary] = [
		{"offset": Vector3i(chunk_size, 0, 0), "axis": 0, "layer": 0},
		{"offset": Vector3i(-chunk_size, 0, 0), "axis": 0, "layer": chunk_size - 1},
		{"offset": Vector3i(0, chunk_size, 0), "axis": 1, "layer": 0},
		{"offset": Vector3i(0, -chunk_size, 0), "axis": 1, "layer": chunk_size - 1},
		{"offset": Vector3i(0, 0, chunk_size), "axis": 2, "layer": 0},
		{"offset": Vector3i(0, 0, -chunk_size), "axis": 2, "layer": chunk_size - 1},
	]
	
	for check: Dictionary in boundary_checks:
		var neighbor_chunk_key: Vector3i = new_chunk_world_key + check["offset"]
		var neighbor_chunk: Chunk = get_loaded_chunk(neighbor_chunk_key)
		if neighbor_chunk == null or not neighbor_chunk.is_inside_tree():
			continue
			
		var new_chunk_layer: int = chunk_size - 1 - check["layer"]
		
		if _boundary_has_water(new_chunk, new_chunk_layer, check["axis"]) or _boundary_has_water(neighbor_chunk, check["layer"], check["axis"]):
			_queue_neighbor_rebuild(neighbor_chunk_key)
		
		_wake_water_on_boundary_layer(neighbor_chunk, neighbor_chunk_key, check["axis"], check["layer"])
		_seed_water_across_new_chunk_boundary(new_chunk, new_chunk_layer, check["axis"])


func _boundary_has_water(chunk: Chunk, layer: int, axis: int) -> bool:
	for a: int in range(chunk_size):
		for b: int in range(chunk_size):
			var local_position: Vector3i
			if axis == 0:
				local_position = Vector3i(layer, a, b)
			elif axis == 1:
				local_position = Vector3i(a, layer, b)
			else:
				local_position = Vector3i(a, b, layer)
				
			if TerrianData.is_water(chunk.chunk_data.get_voxel(local_position)):
				return true
	return false


func _seed_water_across_new_chunk_boundary(new_chunk: Chunk, layer: int, axis: int) -> void:
	if water_flow_manager == null:
		return
	
	for a: int in range(chunk_size):
		for b: int in range(chunk_size):
			var local_position: Vector3i
			if axis == 0:
				local_position = Vector3i(layer, a, b)
			elif axis == 1:
				local_position = Vector3i(a, layer, b)
			else:
				local_position = Vector3i(a, b, layer)
				
			if TerrianData.is_water(new_chunk.chunk_data.get_voxel(local_position)):
				water_flow_manager.enqueue(new_chunk.chunk_world_origin + local_position)


func _wake_water_on_boundary_layer(neighbor_chunk: Chunk, neighbor_chunk_key: Vector3i, axis: int, layer: int) -> void:
	for a: int in range(chunk_size):
		for b: int in range(chunk_size):
			var local_position: Vector3i
			if axis == 0:
				local_position = Vector3i(layer, a, b)
			elif axis == 1:
				local_position = Vector3i(a, layer, b)
			else:
				local_position = Vector3i(a, b, layer)
				
			var voxel_type: TerrianData.TerrianType = neighbor_chunk.chunk_data.get_voxel(local_position)
			if TerrianData.is_water(voxel_type):
				water_flow_manager.enqueue(neighbor_chunk_key + local_position)


#-###########################################
# Coordinate Helpers
#-###########################################

func _world_to_chunk_grid_coord(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_position.x / float(chunk_size)),
		floori(world_position.y / float(chunk_size)),
		floori(world_position.z / float(chunk_size))
	)


func _chunk_grid_to_world_key(grid_coord: Vector3i) -> Vector3i:
	return Vector3i(
		grid_coord.x * chunk_size,
		grid_coord.y * chunk_size,
		grid_coord.z * chunk_size
	)


#-###########################################
# Movement Direction Tracking
#-###########################################

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
	
	if delta_xz.length() < 0.01:
		return
		
	var new_direction: Vector2 = delta_xz.normalized()
	
	if movement_direction_xz.dot(new_direction) < direction_change_dot_threshold:
		load_queue.clear()
		
	movement_direction_xz = new_direction

#-###########################################
# Streaming Update
#-###########################################

func _update_streaming() -> void:
	var center_world_position: Vector3 = stream_target.global_position if stream_target != null else Vector3.ZERO
	var center_chunk_grid: Vector3i = _world_to_chunk_grid_coord(center_world_position)
	
	if center_chunk_grid == last_center_chunk_coord:
		return
		
	last_center_chunk_coord = center_chunk_grid
	
	_queue_needed_chunks(center_chunk_grid)
	_unload_distant_chunks(center_chunk_grid)


#-###########################################
# Forward Cone Helper
#-###########################################

func _is_chunk_ahead(offset_grid_2d: Vector2i) -> bool:
	if offset_grid_2d == Vector2i.ZERO:
		return true
		
	var offset_direction: Vector2 = Vector2(offset_grid_2d.x, offset_grid_2d.y).normalized()
	var alignment: float = offset_direction.dot(movement_direction_xz)
	return alignment >= forward_dot_threshold


#-###########################################
# Queueing Chunks to Load
#-###########################################

func _get_needed_grid_y_values(center_chunk_grid_y: int, grid_x: int, grid_z: int) -> Array[int]:
	var grid_y_values: Array[int] = []
	
	var player_min_grid_y: int = max(0, center_chunk_grid_y - 1)
	var player_max_grid_y: int = min(number_of_chunks.y - 1, center_chunk_grid_y + 1)
	
	for grid_y: int in range(player_min_grid_y, player_max_grid_y + 1):
		grid_y_values.append(grid_y)
		
	var world_x: float = grid_x * chunk_size + chunk_size * 0.5
	var world_z: float = grid_z * chunk_size + chunk_size * 0.5
	
	var surface_grid_y: int = _estimate_surface_grid_y(world_x, world_z)
	var surface_min_grid_y: int = max(0, surface_grid_y - surface_visible_chunks_below)
	
	for grid_y: int in range(surface_min_grid_y, surface_grid_y + 1):
		if not grid_y_values.has(grid_y):
			grid_y_values.append(grid_y)
			
	var water_range: Vector2i = _get_water_grid_y_range(grid_x, grid_z)
	if water_range.x != -1:
		for grid_y: int in range(water_range.x, water_range.y + 1):
			if not grid_y_values.has(grid_y):
				grid_y_values.append(grid_y)
				
	return grid_y_values


func _get_water_grid_y_range(grid_x: int, grid_z: int) -> Vector2i:
	var world_x: float = grid_x * chunk_size + chunk_size * 0.5
	var world_z: float = grid_z * chunk_size + chunk_size * 0.5
	
	var estimated_surface_height: float = _height_probe.get_final_height(
		world_x,
		world_z,
		terrain_base_height,
		terrain_amplitude,
		terrain_noise,
		mountain_biome_noise,
		_height_probe.mountain_shape_noise,
		_height_probe.steep_noise
	)
	
	if estimated_surface_height >= water_level:
		return Vector2i(-1, -1)
		
	var surface_grid_y: int = clampi(floori(estimated_surface_height / float(chunk_size)), 0, number_of_chunks.y - 1)
	var water_grid_y: int = clampi(floori(water_level / float(chunk_size)), 0, number_of_chunks.y - 1)
	
	return Vector2i(surface_grid_y, water_grid_y)


func _queue_needed_chunks(center_chunk_grid: Vector3i) -> void:
	var needed_chunk_keys: Array[Vector3i] = []
	
	for grid_x: int in range(center_chunk_grid.x - view_distance_in_chunks, center_chunk_grid.x + view_distance_in_chunks + 1):
		for grid_z: int in range(center_chunk_grid.z - view_distance_in_chunks, center_chunk_grid.z + view_distance_in_chunks + 1):
			
			var offset_grid_2d: Vector2i = Vector2i(grid_x - center_chunk_grid.x, grid_z - center_chunk_grid.z)
			var distance_in_chunks: int = maxi(absi(offset_grid_2d.x), absi(offset_grid_2d.y))
			
			if distance_in_chunks > view_distance_in_chunks:
				continue
				
			if grid_x < 0 or grid_x >= number_of_chunks.x:
				continue
			if grid_z < 0 or grid_z >= number_of_chunks.z:
				continue
				
			if distance_in_chunks > core_radius_in_chunks and not _is_chunk_ahead(offset_grid_2d):
				continue
				
			var grid_y_values: Array[int] = _get_needed_grid_y_values(center_chunk_grid.y, grid_x, grid_z)
			
			for grid_y: int in grid_y_values:
				var chunk_grid_coord: Vector3i = Vector3i(grid_x, grid_y, grid_z)
				var chunk_world_key: Vector3i = _chunk_grid_to_world_key(chunk_grid_coord)
				
				chunks_mutex.lock()
				var already_loaded: bool = chunks_by_key.has(chunk_world_key)
				chunks_mutex.unlock()
				if already_loaded:
					continue
					
				loading_chunks_mutex.lock()
				var already_loading: bool = loading_chunks_flags.has(chunk_world_key)
				loading_chunks_mutex.unlock()
				if already_loading:
					continue
					
				if chunk_world_key in load_queue:
					continue
					
				needed_chunk_keys.append(chunk_world_key)
				
	if needed_chunk_keys.is_empty():
		return
		
	load_queue.append_array(needed_chunk_keys)
	
	var center_world_x: int = center_chunk_grid.x * chunk_size
	var center_world_z: int = center_chunk_grid.z * chunk_size
	var movement_direction: Vector2 = movement_direction_xz
	
	load_queue.sort_custom(func(first_key: Vector3i, second_key: Vector3i) -> bool:
		var first_grid_offset: Vector2i = Vector2i(int(first_key.x / float(chunk_size)) - center_chunk_grid.x, int(first_key.z / float(chunk_size)) - center_chunk_grid.z)
		var second_grid_offset: Vector2i = Vector2i(int(second_key.x / float(chunk_size)) - center_chunk_grid.x, int(second_key.z / float(chunk_size)) - center_chunk_grid.z)
		
		var first_distance: int = maxi(absi(first_grid_offset.x), absi(first_grid_offset.y))
		var second_distance: int = maxi(absi(second_grid_offset.x), absi(second_grid_offset.y))
		
		var first_is_core: bool = first_distance <= core_radius_in_chunks
		var second_is_core: bool = second_distance <= core_radius_in_chunks
		
		if first_is_core != second_is_core:
			return first_is_core
			
		var first_squared_distance: int = (first_key.x - center_world_x) * (first_key.x - center_world_x) + (first_key.z - center_world_z) * (first_key.z - center_world_z)
		var second_squared_distance: int = (second_key.x - center_world_x) * (second_key.x - center_world_x) + (second_key.z - center_world_z) * (second_key.z - center_world_z)
		
		if first_squared_distance != second_squared_distance:
			return first_squared_distance < second_squared_distance
			
		var first_alignment: float = Vector2(first_grid_offset.x, first_grid_offset.y).normalized().dot(movement_direction) if first_grid_offset != Vector2i.ZERO else 1.0
		var second_alignment: float = Vector2(second_grid_offset.x, second_grid_offset.y).normalized().dot(movement_direction) if second_grid_offset != Vector2i.ZERO else 1.0
		
		return first_alignment > second_alignment
	)


func queue_tree_voxel(world_position: Vector3i, voxel_type: TerrianData.TerrianType) -> void:
	if voxel_type == TerrianData.TerrianType.WOOD:
		var below_type: TerrianData.TerrianType = get_voxel_type_at(world_position + Vector3i.DOWN)
		if TerrianData.is_water(below_type):
			return
			
	var chunk_world_key: Vector3i = _voxel_to_chunk_key(world_position)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	
	if chunk != null:
		var local_pos: Vector3i = world_position - chunk_world_key
		if chunk.chunk_data.get_voxel(local_pos) == TerrianData.TerrianType.WATER:
			return
		chunk.chunk_data.add_voxel(local_pos, voxel_type)
		_queue_neighbor_rebuild(chunk_world_key)
		return
		
	pending_tree_edits_mutex.lock()
	if not pending_tree_edits.has(chunk_world_key):
		pending_tree_edits[chunk_world_key] = []
	pending_tree_edits[chunk_world_key].append({"pos": world_position - chunk_world_key, "type": voxel_type})
	pending_tree_edits_mutex.unlock()


func _queue_neighbor_rebuild(chunk_world_key: Vector3i) -> void:
	_pending_neighbor_rebuilds_mutex.lock()
	if not _pending_neighbor_rebuilds_flags.has(chunk_world_key):
		_pending_neighbor_rebuilds_flags[chunk_world_key] = true
		_pending_neighbor_rebuilds.append(chunk_world_key)
	_pending_neighbor_rebuilds_mutex.unlock()

#-###########################################
# Dispatching Chunk Generation
#-###########################################

func _dispatch_load_queue() -> void:
	if is_thread_stopping: return
	var count: int = min(dispatch_chunks_per_frame, load_queue.size())
	for index: int in range(count):
		var chunk_world_key: Vector3i = load_queue.pop_front()
		
		loading_chunks_mutex.lock()
		loading_chunks_flags[chunk_world_key] = true
		loading_chunks_mutex.unlock()
		
		var grid_coord: Vector3i = Vector3i(
			int(chunk_world_key.x / float(chunk_size)),
			int(chunk_world_key.y / float(chunk_size)),
			int(chunk_world_key.z / float(chunk_size))
		)
		
		var task_id: int = WorkerThreadPool.add_task(_generate_chunk_at.bind(grid_coord), false, "chunk_generation")
		active_task_ids.append(task_id)


#-###########################################
# Unloading Distant Chunks
#-###########################################

func _unload_distant_chunks(center_chunk_grid: Vector3i) -> void:
	var ahead_unload_distance_in_chunks: int = view_distance_in_chunks + unload_buffer_in_chunks
	var behind_unload_distance_in_chunks: int = core_radius_in_chunks + behind_unload_buffer_in_chunks
	var vertical_unload_distance: int = view_distance_in_chunks_y + unload_buffer_in_chunks_y
	
	chunks_mutex.lock()
	var keys: Array = chunks_by_key.keys()
	chunks_mutex.unlock()
	
	for key in keys:
		var grid_x: int = key.x / chunk_size
		var grid_y: int = key.y / chunk_size
		var grid_z: int = key.z / chunk_size
		
		var offset_grid_2d: Vector2i = Vector2i(grid_x - center_chunk_grid.x, grid_z - center_chunk_grid.z)
		var distance_in_chunks: int = maxi(absi(offset_grid_2d.x), absi(offset_grid_2d.y))
		var vertical_distance: int = absi(grid_y - center_chunk_grid.y)
		
		var world_x: float = grid_x * chunk_size + chunk_size * 0.5
		var world_z: float = grid_z * chunk_size + chunk_size * 0.5
		var surface_grid_y: int = _estimate_surface_grid_y(world_x, world_z)
		var surface_min_grid_y: int = max(0, surface_grid_y - surface_visible_chunks_below)
		var is_surface_chunk: bool = grid_y >= surface_min_grid_y and grid_y <= surface_grid_y
		
		var water_range: Vector2i = _get_water_grid_y_range(grid_x, grid_z)
		var is_underwater_chunk: bool = water_range.x != -1 and grid_y >= water_range.x and grid_y <= water_range.y
		
		var should_unload: bool = false
		
		if not is_surface_chunk and not is_underwater_chunk and vertical_distance > vertical_unload_distance:
			should_unload = true
		elif distance_in_chunks > core_radius_in_chunks:
			var unload_distance: int = ahead_unload_distance_in_chunks if _is_chunk_ahead(offset_grid_2d) else behind_unload_distance_in_chunks
			if distance_in_chunks > unload_distance:
				should_unload = true
				
		if should_unload:
			chunks_mutex.lock()
			var chunk: Chunk = chunks_by_key.get(key)
			var still_pending: bool = chunk != null and not chunk.is_inside_tree()
			if chunk != null and not still_pending:
				chunks_by_key.erase(key)
			chunks_mutex.unlock()
			
			if chunk != null and not still_pending:
				chunk.queue_free()


#-###########################################
# Chunk Generation (Threaded)
#-###########################################

func _generate_chunk_at(chunk_grid_coord: Vector3i) -> void:
	if is_thread_stopping: return
	var new_chunk: Chunk = chunk_scene.instantiate() as Chunk
	new_chunk.chunk_manager = self
	
	new_chunk.position = Vector3(
		chunk_grid_coord.x,
		chunk_grid_coord.y,
		chunk_grid_coord.z
	) * float(chunk_size)
	
	new_chunk.chunk_world_origin = chunk_grid_coord * chunk_size
	
	if is_thread_stopping: return
	
	new_chunk.generate_date(
		chunk_size,
		terrain_base_height,
		terrain_amplitude,
		terrain_noise,
		cave_noise,
		cave_threshold,
		cave_below_surface_min,
		cave_below_surface_max,
		cave_entrance_noise,
		cave_entrance_region_threshold,
		cave_entrance_surface_reach,
		mountain_biome_noise,
		water_level,
		tree_noise,
		mountain_biome_threshold
	)
	
	var chunk_world_key: Vector3i = Vector3i(new_chunk.position)
	
	if modified_chunks.has(chunk_world_key):
		var saved_voxels: PackedInt32Array = modified_chunks[chunk_world_key]
		new_chunk.chunk_data.voxels = saved_voxels
		new_chunk.chunk_data.voxel_amount = _count_non_air(saved_voxels)
	else:
		pending_tree_edits_mutex.lock()
		var queued_edits: Array = pending_tree_edits.get(chunk_world_key, [])
		pending_tree_edits.erase(chunk_world_key)
		pending_tree_edits_mutex.unlock()
		
		for edit: Dictionary in queued_edits:
			var local_pos: Vector3i = edit["pos"]
			var voxel_type: TerrianData.TerrianType = edit["type"]
			
			if new_chunk.chunk_data.get_voxel(local_pos) == TerrianData.TerrianType.WATER:
				continue
				
			if voxel_type == TerrianData.TerrianType.WOOD:
				var below_pos: Vector3i = local_pos + Vector3i.DOWN
				if below_pos.y >= 0 and new_chunk.chunk_data.get_voxel(below_pos) == TerrianData.TerrianType.WATER:
					continue
					
			new_chunk.chunk_data.add_voxel(local_pos, voxel_type)
		
	new_chunk.generate_mesh()
	
	if is_thread_stopping: return
	
	new_chunk.compute_collision_boxes()
	
	if is_thread_stopping: return
	
	chunks_mutex.lock()
	chunks_by_key[chunk_world_key] = new_chunk
	chunks_mutex.unlock()
	
	pending_chunks_mutex.lock()
	pending_chunks_to_add.append(new_chunk)
	pending_chunks_mutex.unlock()
	
	loading_chunks_mutex.lock()
	loading_chunks_flags.erase(chunk_world_key)
	loading_chunks_mutex.unlock()


#-###########################################
# Voxel Editing Helpers
#-###########################################

func _voxel_to_chunk_key(voxel_position: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(voxel_position.x) / float(chunk_size)) * chunk_size,
		floori(float(voxel_position.y) / float(chunk_size)) * chunk_size,
		floori(float(voxel_position.z) / float(chunk_size)) * chunk_size
	)


func add_voxel_at_position(target_block: Vector3i, voxel_type: TerrianData.TerrianType) -> void:
	var chunk_world_key: Vector3i = _voxel_to_chunk_key(target_block)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return
		
	var local_voxel_position: Vector3i = target_block - chunk_world_key
	chunk.set_voxel(local_voxel_position, voxel_type)
	_store_modified_chunk(chunk_world_key, chunk)
	
	if water_flow_manager != null:
		if TerrianData.is_water(voxel_type):
			water_flow_manager.enqueue(target_block)
		water_flow_manager.wake_neighbors(target_block)


func remove_voxel_at_position(target_block: Vector3i) -> void:
	var chunk_world_key: Vector3i = _voxel_to_chunk_key(target_block)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return
		
	var local_voxel_position: Vector3i = target_block - chunk_world_key
	chunk.remove_voxel_at_local(local_voxel_position)
	_store_modified_chunk(chunk_world_key, chunk)
	
	if water_flow_manager != null:
		water_flow_manager.wake_neighbors(target_block)


#-###########################################
# Water Simulation Lookups
#-###########################################

func get_voxel_type_at(world_position: Vector3i) -> TerrianData.TerrianType:
	var chunk_world_key: Vector3i = _voxel_to_chunk_key(world_position)
	
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	
	if chunk == null:
		return TerrianData.TerrianType.AIR
		
	var local_position: Vector3i = world_position - chunk_world_key
	return chunk.chunk_data.get_voxel(local_position)


func voxel_to_chunk_key(world_position: Vector3i) -> Vector3i:
	return _voxel_to_chunk_key(world_position)


func is_chunk_loaded_at_key(chunk_world_key: Vector3i) -> bool:
	chunks_mutex.lock()
	var loaded: bool = chunks_by_key.has(chunk_world_key)
	chunks_mutex.unlock()
	return loaded


func get_loaded_chunk(chunk_world_key: Vector3i) -> Chunk:
	chunks_mutex.lock()
	var chunk: Chunk = chunks_by_key.get(chunk_world_key)
	chunks_mutex.unlock()
	return chunk


#-###########################################
# World / Local Conversion
#-###########################################

func _world_to_chunk_key(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori((world_position.x + 0.5) / float(chunk_size)) * chunk_size,
		floori((world_position.y + 0.5) / float(chunk_size)) * chunk_size,
		floori((world_position.z + 0.5) / float(chunk_size)) * chunk_size
	)


func _world_to_local_voxel_centered(world_position: Vector3, chunk_world_key: Vector3i) -> Vector3i:
	return Vector3i(
		roundi(world_position.x) - chunk_world_key.x,
		roundi(world_position.y) - chunk_world_key.y,
		roundi(world_position.z) - chunk_world_key.z
	)


#-###########################################
# Spawn Height / Column Checks
#-###########################################

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
	return int(get_highest_voxel_at_xz(world_x, world_z))


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


#-###########################################
# Cleanup
#-###########################################

func _exit_tree() -> void:
	for id: int in active_task_ids:
		WorkerThreadPool.wait_for_task_completion(id)


#-###########################################
# Modified Chunk Storage
#-###########################################

func _store_modified_chunk(chunk_world_key: Vector3i, chunk: Chunk) -> void:
	modified_chunks[chunk_world_key] = chunk.chunk_data.get_voxels_copy()


#-###########################################
# Other Helpers
#-###########################################

func _count_non_air(voxels: PackedInt32Array) -> int:
	var count: int = 0
	for voxel_value in voxels:
		if voxel_value != TerrianData.TerrianType.AIR:
			count += 1
	return count


func notify_player_spawned() -> void:
	vertical_streaming_locked_to_spawn = false


#-###########################################
# Player Signals
#-###########################################

func _on_player_add_block(target_block: Vector3i, _normal: Vector3i, terrain_type: TerrianData.TerrianType) -> void:
	add_voxel_at_position(target_block, terrain_type)


func _on_player_remove_block(target_block: Vector3i) -> void:
	remove_voxel_at_position(target_block)


#-###########################################
# Thread Stopping
#-###########################################

func request_shutdown() -> void:
	is_thread_stopping = true
	load_queue.clear()
	_pending_neighbor_rebuilds.clear()
	_pending_neighbor_rebuilds_flags.clear()
