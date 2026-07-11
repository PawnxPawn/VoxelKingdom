class_name Chunk extends StaticBody3D

#-###########################################
#              Enums & Constants
#-###########################################
enum Face {
	BOTTOM,
	FRONT,
	RIGHT,
	TOP,
	LEFT,
	BACK,
}

@export var use_centered_voxels: bool = false
@export var material: Material
@export var stone_height: int = 45
@export var dirt_depth: int = 3
@export var bedrock_height: int = 2
@export var atlas_columns: int = 3

const MOUNTAIN_GRASS_CHANCE: float = 0.20

#-###########################################
#              Node References
#-###########################################
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

#-###########################################
#              Chunk Data & State
#-###########################################
static var cube_count: int = 0

var chunk_data: ChunkData = ChunkData.new()
var voxel_colors: Dictionary[TerrianData.TerrianType, Color] = {}
var chunk_size: int = 0

var mesh_data: MeshData = MeshData.new()
var collision_faces: PackedVector3Array = PackedVector3Array()
var pending_collision_boxes: Array[Dictionary] = []

var rebuild_mutex: Mutex = Mutex.new()
var rebuild_running: bool = false
var rebuild_dirty: bool = false
var active_task_id: int = -1

var provisional_shape: CollisionShape3D = null

#-###########################################
#              Face Data
#-###########################################
var face_normals: Dictionary[Face, Vector3] = {
	Face.FRONT: Vector3(0, 0, 1),
	Face.BACK: Vector3(0, 0, -1),
	Face.LEFT: Vector3(-1, 0, 0),
	Face.RIGHT: Vector3(1, 0, 0),
	Face.BOTTOM: Vector3(0, -1, 0),
	Face.TOP: Vector3(0, 1, 0),
}

var face_axes: Dictionary[Face, FaceAxes] = {
	Face.FRONT: FaceAxes.new(2, 1, 0, 1, 1, 1),
	Face.BACK: FaceAxes.new(2, -1, 0, -1, 1, 1),
	Face.RIGHT: FaceAxes.new(0, 1, 1, 1, 2, 1),
	Face.LEFT: FaceAxes.new(0, -1, 2, 1, 1, 1),
	Face.TOP: FaceAxes.new(1, 1, 2, 1, 0, 1),
	Face.BOTTOM: FaceAxes.new(1, -1, 0, 1, 2, 1),
}

# How many 90-degree steps to rotate each face's texture (0-3).
var face_uv_rotation: Dictionary[Face, int] = {
	Face.FRONT: 2,
	Face.BACK: 2,
	Face.RIGHT: 1,
	Face.LEFT: 2,
	Face.TOP: 0,
	Face.BOTTOM: 0,
}

var mountain_shape_noise: FastNoiseLite
var steep_noise: FastNoiseLite


func _init() -> void:
	mountain_shape_noise = FastNoiseLite.new()
	mountain_shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	mountain_shape_noise.frequency = 0.0012
	mountain_shape_noise.seed = 99991
	
	steep_noise = FastNoiseLite.new()
	steep_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	steep_noise.frequency = 0.004
	steep_noise.seed = 55512


func _ready() -> void:
	mesh_instance.mesh = ArrayMesh.new()
	collision_shape_3d.disabled = true
	
	if material is ShaderMaterial:
		material.set_shader_parameter("tile_size", 1.0 / atlas_columns)
		
	mountain_shape_noise = FastNoiseLite.new()
	mountain_shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	mountain_shape_noise.frequency = 0.0012
	mountain_shape_noise.seed = 99991
	
	steep_noise = FastNoiseLite.new()
	steep_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	steep_noise.frequency = 0.004
	steep_noise.seed = 55512
	
	if chunk_data.is_empty():
		return
		
	commit_mesh()

#-###########################################
#              Terrain Helpers
#-###########################################
func get_directional_slope_mask(world_x: float, world_z: float) -> float:
	var direction_x: float = abs(world_x * 0.0008)
	var direction_z: float = abs(world_z * 0.0008)
	var directional_sum: float = clamp(direction_x + direction_z, 0.0, 1.0)
	return 1.0 - directional_sum


func get_grass_probability(world_y: float, terrain_base_height: float, terrain_amplitude: float) -> float:
	var low_altitude: float = terrain_base_height + terrain_amplitude * 0.3
	var mid_altitude: float = terrain_base_height + terrain_amplitude * 1.0
	var high_altitude: float = terrain_base_height + terrain_amplitude * 1.8
	
	if world_y <= low_altitude:
		return 1.0
	if world_y <= mid_altitude:
		return 1.0 - ((world_y - low_altitude) / (mid_altitude - low_altitude))
	if world_y <= high_altitude:
		return 0.25 - ((world_y - mid_altitude) / (high_altitude - mid_altitude)) * 0.25
		
	return 0.0


func get_final_height(
	world_x: float,
	world_z: float,
	terrain_base_height: float,
	terrain_amplitude: float,
	terrain_noise: Noise,
	mountain_biome_noise: Noise,
	mountain_shape_noise_local: FastNoiseLite,
	steep_noise_local: FastNoiseLite
) -> float:
	
	var ground_level: float = terrain_base_height
	
	# Hills
	var hill_noise_value: float = terrain_noise.get_noise_2d(world_x, world_z)
	var hill_normalized: float = (hill_noise_value + 1.0) * 0.5
	var hill_curve: float = pow(hill_normalized, 1.8)
	var hill_height: float = (hill_curve - 0.5) * (terrain_amplitude * 0.4)
	var final_height: float = ground_level + hill_height
	
	# Mountain biome
	var biome_value: float = mountain_biome_noise.get_noise_2d(world_x, world_z)
	var biome_normalized: float = (biome_value + 1.0) * 0.5
	var is_mountain: bool = biome_normalized > 0.80
	
	if is_mountain:
		var shape_value: float = mountain_shape_noise_local.get_noise_2d(world_x, world_z)
		var shape_normalized: float = (shape_value + 1.0) * 0.5
		
		var base_curve: float = pow(shape_normalized, 1.2)
		var ramp_curve: float = pow(shape_normalized, 2.0)
		var peak_curve: float = pow(shape_normalized, 4.0)
		
		var detail_noise_1: float = terrain_noise.get_noise_2d(world_x * 2.0, world_z * 2.0)
		var detail_noise_2: float = terrain_noise.get_noise_2d(world_x * 4.0, world_z * 4.0)
		var detail_noise_3: float = terrain_noise.get_noise_2d(world_x * 8.0, world_z * 8.0)
		var detail_noise_sum: float = (detail_noise_1 * 0.6) + (detail_noise_2 * 0.3) + (detail_noise_3 * 0.1)
		var detail_normalized: float = (detail_noise_sum + 1.0) * 0.5
		var detail_curve: float = pow(detail_normalized, 2.0)
		
		var steep_value: float = steep_noise_local.get_noise_2d(world_x, world_z)
		var steep_normalized: float = (steep_value + 1.0) * 0.5
		var steep_multiplier: float = lerp(1.0, 2.0, steep_normalized)
		
		var slope_mask: float = get_directional_slope_mask(world_x, world_z)
		var directional_multiplier: float = lerp(0.5, 1.0, slope_mask)
		
		var biome_falloff: float = clamp((biome_normalized - 0.80) / 0.20, 0.0, 1.0)
		
		var mountain_height: float = base_curve * (terrain_amplitude * 1.2) * biome_falloff * directional_multiplier + ramp_curve * (terrain_amplitude * 1.8) * biome_falloff * directional_multiplier + peak_curve * (terrain_amplitude * 1.2) * biome_falloff * steep_multiplier + detail_curve * (terrain_amplitude * 0.6) * biome_falloff
		
		final_height += mountain_height
		
	return final_height

#-###########################################
#              Terrain Generation
#-###########################################
func generate_date(
	size: int,
	terrain_base_height: float,
	terrain_amplitude: float,
	terrain_noise: Noise,
	terrain_colors: Dictionary[TerrianData.TerrianType, Color],
	cave_noise: Noise = null,
	cave_threshold: float = 0.62,
	cave_below_surface_minimum: int = 8,
	cave_below_surface_maximum: int = 150,
	cave_entrance_noise: Noise = null,
	cave_entrance_region_threshold: float = 0.72,
	cave_entrance_surface_reach: int = 6,
	mountain_biome_noise: Noise = null
) -> void:
	
	chunk_size = size
	chunk_data.set_size(size)
	voxel_colors = terrain_colors
	
	# Height cache
	var height_cache: Array[Array] = []
	height_cache.resize(size)
	for x_index in range(size):
		height_cache[x_index] = []
		height_cache[x_index].resize(size)
		
	# Biome cache
	var biome_cache: Array[Array] = []
	biome_cache.resize(size)
	for x_index in range(size):
		biome_cache[x_index] = []
		biome_cache[x_index].resize(size)
		
	# Cave entrance cache
	var cave_entrance_cache: Array[Array] = []
	cave_entrance_cache.resize(size)
	for x_index in range(size):
		cave_entrance_cache[x_index] = []
		cave_entrance_cache[x_index].resize(size)
		
	# Precompute heights, biomes, cave entrance flags
	for voxel_x: int in range(size):
		for voxel_z: int in range(size):
			
			var world_position: Vector3 = position + Vector3(voxel_x, 0, voxel_z)
			
			var terrain_height: float = get_final_height(world_position.x, world_position.z, terrain_base_height, terrain_amplitude, terrain_noise, mountain_biome_noise, mountain_shape_noise, steep_noise)
			height_cache[voxel_x][voxel_z] = terrain_height
			
			var biome_value: float = mountain_biome_noise.get_noise_2d(world_position.x, world_position.z)
			var biome_normalized: float = (biome_value + 1.0) * 0.5
			var is_mountain: bool = biome_normalized > 0.80
			biome_cache[voxel_x][voxel_z] = is_mountain
			
			var cave_entrance_allowed: bool = false
			if cave_entrance_noise != null:
				var entrance_noise_value: float = cave_entrance_noise.get_noise_2d(world_position.x, world_position.z)
				var entrance_normalized: float = clampf((entrance_noise_value + 1.0) * 0.5, 0.0, 1.0)
				if entrance_normalized > cave_entrance_region_threshold:
					cave_entrance_allowed = true
			cave_entrance_cache[voxel_x][voxel_z] = cave_entrance_allowed
			
	# Fill voxels
	for voxel_x: int in range(size):
		for voxel_z: int in range(size):
			
			var terrain_height: float = height_cache[voxel_x][voxel_z]
			if terrain_height < position.y:
				continue
				
			var local_column_height: float = terrain_height - position.y
			var world_surface_y: float = position.y + local_column_height
			
			var left_x: int = max(voxel_x - 1, 0)
			var right_x: int = min(voxel_x + 1, size - 1)
			var up_z: int = min(voxel_z + 1, size - 1)
			var down_z: int = max(voxel_z - 1, 0)
			
			var height_left: float = height_cache[left_x][voxel_z]
			var height_right: float = height_cache[right_x][voxel_z]
			var height_up: float = height_cache[voxel_x][up_z]
			var height_down: float = height_cache[voxel_x][down_z]
			
			var slope_x: float = abs(height_left - height_right)
			var slope_z: float = abs(height_up - height_down)
			var column_slope: float = clamp(max(slope_x, slope_z) / 12.0, 0.0, 1.0)
			
			var is_mountain: bool = biome_cache[voxel_x][voxel_z]
			var cave_entrance_allowed: bool = cave_entrance_cache[voxel_x][voxel_z]
			
			var cave_minimum_depth_adjusted: int = cave_below_surface_minimum
			if cave_entrance_allowed:
				cave_minimum_depth_adjusted = -cave_entrance_surface_reach
				
			var cave_upper_y: int = int(world_surface_y) - cave_minimum_depth_adjusted
			var cave_lower_y: int = int(world_surface_y) - cave_below_surface_maximum
			
			for voxel_y: int in range(min(local_column_height, size)):
				
				var depth_from_surface: int = int(local_column_height) - 1 - voxel_y
				var world_y: int = int(position.y) + voxel_y
				
				var terrain_type: TerrianData.TerrianType
				
				if world_y <= bedrock_height:
					terrain_type = TerrianData.TerrianType.BEDROCK
					
				elif cave_entrance_allowed:
					terrain_type = TerrianData.TerrianType.STONE
					
				elif depth_from_surface == 0:
					
					var grass_chance: float = get_grass_probability(world_y, terrain_base_height, terrain_amplitude)
					var mountain_grass_chance: float = MOUNTAIN_GRASS_CHANCE if is_mountain else  1.0
					var final_grass_chance: float = grass_chance * mountain_grass_chance
					
					if column_slope >= 0.55:
						terrain_type = TerrianData.TerrianType.STONE
					elif column_slope < 0.25:
						terrain_type = TerrianData.TerrianType.GRASS if randf() < final_grass_chance else TerrianData.TerrianType.STONE
					else:
						terrain_type = TerrianData.TerrianType.GRASS if randf() < final_grass_chance * 0.4 else TerrianData.TerrianType.STONE
						
				elif depth_from_surface <= dirt_depth:
					terrain_type = TerrianData.TerrianType.DIRT
					
				else:
					terrain_type = TerrianData.TerrianType.STONE
					
				if cave_noise != null and terrain_type != TerrianData.TerrianType.BEDROCK and world_y >= max(bedrock_height + 1, cave_lower_y) and world_y <= cave_upper_y:
					var cave_value: float = cave_noise.get_noise_3d(position.x + voxel_x, float(world_y), position.z + voxel_z)
					var cave_normalized: float = clampf((cave_value + 1.0) * 0.5, 0.0, 1.0)
					if cave_normalized > cave_threshold:
						continue
						
				chunk_data.add_voxel(Vector3i(voxel_x, voxel_y, voxel_z), terrain_type)
				cube_count += 1

#-###########################################
#              Mesh Generation
#-###########################################
func generate_mesh() -> void:
	if chunk_data.is_empty():
		mesh_data.reset()
		return
		
	mesh_data.reset()
	collision_faces.clear()
	
	var flat_voxels: PackedInt32Array = chunk_data.get_voxels_copy()
	
	for face: Face in Face.values():
		mesh_face(face, flat_voxels)


func mesh_face(face: Face, flat_voxels: PackedInt32Array) -> void:
	var axes: FaceAxes = face_axes[face]
	var normal: Vector3 = face_normals[face]
	
	for layer: int in range(chunk_size):
		var mask: PackedInt32Array = PackedInt32Array()
		mask.resize(chunk_size * chunk_size)
		mask.fill(-1)
		
		for across: int in range(chunk_size):
			for up: int in range(chunk_size):
				var position_index: Vector3i = Vector3i.ZERO
				position_index[axes.normal_axis] = layer
				position_index[axes.across_axis] = across
				position_index[axes.up_axis] = up
				
				var voxel_value: int = flat_voxels[position_index.x + position_index.z * chunk_size + position_index.y * chunk_size * chunk_size]
				if voxel_value == TerrianData.TerrianType.AIR:
					continue
					
				var neighbor_position: Vector3i = position_index + Vector3i(normal)
				var mask_index: int = across * chunk_size + up
				
				if neighbor_position.x < 0 or neighbor_position.y < 0 or neighbor_position.z < 0 or neighbor_position.x >= chunk_size or neighbor_position.y >= chunk_size or neighbor_position.z >= chunk_size:
					mask[mask_index] = voxel_value
					continue
					
				var neighbor_voxel_value: int = flat_voxels[neighbor_position.x + neighbor_position.z * chunk_size + neighbor_position.y * chunk_size * chunk_size]
				
				if neighbor_voxel_value == TerrianData.TerrianType.AIR:
					mask[mask_index] = voxel_value
					continue
					
				var neighbor_is_transparent: bool = TerrianData.is_transparent(neighbor_voxel_value as TerrianData.TerrianType)
				if neighbor_is_transparent:
					if neighbor_voxel_value == voxel_value:
						continue
					mask[mask_index] = voxel_value
					continue
					
				continue
				
		merge_mask(mask, face, axes, layer)


func merge_mask(mask: PackedInt32Array, face: Face, axes: FaceAxes, layer: int) -> void:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(chunk_size * chunk_size)
	
	for across: int in range(chunk_size):
		for up: int in range(chunk_size):
			var start_index: int = across * chunk_size + up
			if visited[start_index] or mask[start_index] == -1:
				continue
				
			var voxel_value: int = mask[start_index]
			var width: int = 1
			
			while across + width < chunk_size:
				var next_index: int = (across + width) * chunk_size + up
				if mask[next_index] != voxel_value or visited[next_index]:
					break
				width += 1
				
			var height: int = 1
			while up + height < chunk_size:
				var row_matches: bool = true
				for delta_x: int in range(width):
					var cell_index: int = (across + delta_x) * chunk_size + (up + height)
					if mask[cell_index] != voxel_value or visited[cell_index]:
						row_matches = false
						break
				if not row_matches:
					break
				height += 1
				
			for delta_x: int in range(width):
				for delta_y: int in range(height):
					visited[(across + delta_x) * chunk_size + (up + delta_y)] = 1
					
			add_quad(face, axes, layer, across, up, width, height, voxel_value as TerrianData.TerrianType)


func add_quad(face: Face, axes: FaceAxes, layer: int, across: int, up: int, width: int, height: int, voxel_type: TerrianData.TerrianType) -> void:
	var across_direction: Vector3 = Vector3.ZERO
	across_direction[axes.across_axis] = axes.across_sign
	
	var up_direction: Vector3 = Vector3.ZERO
	up_direction[axes.up_axis] = axes.up_sign
	
	var origin: Vector3 = Vector3.ZERO
	origin[axes.normal_axis] = layer + 0.5 * axes.normal_sign
	origin[axes.across_axis] = (across - 0.5) if axes.across_sign > 0 else (across + width - 0.5)
	origin[axes.up_axis] = (up - 0.5) if axes.up_sign > 0 else (up + height - 0.5)
	
	var bottom_left: Vector3 = origin
	var top_left: Vector3 = bottom_left + up_direction * height
	var top_right: Vector3 = top_left + across_direction * width
	var bottom_right: Vector3 = bottom_left + across_direction * width
	
	var normal: Vector3 = face_normals[face]
	var corners: Array[Vector3] = [bottom_left, top_left, top_right, bottom_left, top_right, bottom_right]
	
	var color: Color = Color.WHITE
	var atlas: BlockFaceAtlas = TerrianData.atlas_tiles[voxel_type]
	var tile: Vector2i = tile_for_face(face, atlas)
	var tile_size: float = 1.0 / atlas_columns
	var tile_origin: Vector2 = Vector2(tile.x, tile.y) * tile_size
	
	var u0: float = width if axes.across_sign < 0 else 0
	var u1: float = 0 if axes.across_sign < 0 else width
	var v0: float = height if axes.up_sign < 0 else 0
	var v1: float = 0 if axes.up_sign < 0 else height
	
	var repeat_uvs: Array[Vector2] = [
		face_uv(0, 0, u0, u1, v0, v1, face_uv_rotation[face]),
		face_uv(0, 1, u0, u1, v0, v1, face_uv_rotation[face]),
		face_uv(1, 1, u0, u1, v0, v1, face_uv_rotation[face]),
		face_uv(0, 0, u0, u1, v0, v1, face_uv_rotation[face]),
		face_uv(1, 1, u0, u1, v0, v1, face_uv_rotation[face]),
		face_uv(1, 0, u0, u1, v0, v1, face_uv_rotation[face]),
	]
	
	for index in range(corners.size()):
		mesh_data.add_data(corners[index], normal, color, repeat_uvs[index], tile_origin)
		collision_faces.append(corners[index])

#-###########################################
#              UV & Atlas Helpers
#-###########################################

func face_uv(a: int, b: int, u0: float, u1: float, v0: float, v1: float, rotation_steps: int) -> Vector2:
	var normalized_rotation: int = ((rotation_steps % 4) + 4) % 4
	var p: int
	var q: int
	
	match normalized_rotation:
		0:
			p = a
			q = b
		1:
			p = b
			q = 1 - a
		2:
			p = 1 - a
			q = 1 - b
		_:
			p = 1 - b
			q = a
			
	if normalized_rotation % 2 == 0:
		var u: float = u0 if p == 0 else u1
		var v: float = v0 if q == 0 else v1
		return Vector2(u, v)
	else:
		var u: float = v0 if p == 0 else v1
		var v: float = u0 if q == 0 else u1
		return Vector2(u, v)


func tile_for_face(face: Face, atlas: BlockFaceAtlas) -> Vector2i:
	match face:
		Face.TOP:
			return atlas.top
		Face.BOTTOM:
			return atlas.bottom
		_:
			return atlas.side

#-###########################################
#              Collision Generation
#-###########################################
func compute_collision_boxes() -> void:
	if chunk_data.is_empty():
		pending_collision_boxes = []
		return
		
	var flat_voxels: PackedInt32Array = chunk_data.get_voxels_copy()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(chunk_size * chunk_size * chunk_size)
	
	var boxes: Array[Dictionary] = []
	
	for x: int in range(chunk_size):
		for y: int in range(chunk_size):
			for z: int in range(chunk_size):
				var start_index: int = x + z * chunk_size + y * chunk_size * chunk_size
				if flat_voxels[start_index] == TerrianData.TerrianType.AIR or visited[start_index]:
					continue
					
				var max_x: int = x
				while max_x + 1 < chunk_size and flat_voxels[(max_x + 1) + z * chunk_size + y * chunk_size * chunk_size] != TerrianData.TerrianType.AIR:
					max_x += 1
					
				var max_z: int = z
				var can_grow_z: bool = true
				while can_grow_z and max_z + 1 < chunk_size:
					for scan_x: int in range(x, max_x + 1):
						if flat_voxels[scan_x + (max_z + 1) * chunk_size + y * chunk_size * chunk_size] == TerrianData.TerrianType.AIR:
							can_grow_z = false
							break
					if can_grow_z:
						max_z += 1
						
				var max_y: int = y
				var can_grow_y: bool = true
				while can_grow_y and max_y + 1 < chunk_size:
					for scan_x: int in range(x, max_x + 1):
						for scan_z: int in range(z, max_z + 1):
							if flat_voxels[scan_x + scan_z * chunk_size + (max_y + 1) * chunk_size * chunk_size] == TerrianData.TerrianType.AIR:
								can_grow_y = false
								break
						if not can_grow_y:
							break
					if can_grow_y:
						max_y += 1
						
				for scan_x: int in range(x, max_x + 1):
					for scan_y: int in range(y, max_y + 1):
						for scan_z: int in range(z, max_z + 1):
							visited[scan_x + scan_z * chunk_size + scan_y * chunk_size * chunk_size] = 1
							
				var size_vector: Vector3 = Vector3(max_x - x + 1, max_y - y + 1, max_z - z + 1)
				var center_vector: Vector3 = Vector3(
					x + size_vector.x * 0.5 - 0.5,
					y + size_vector.y * 0.5 - 0.5,
					z + size_vector.z * 0.5 - 0.5
				)
				
				boxes.append({"size": size_vector, "center": center_vector})
				
	pending_collision_boxes = boxes


func apply_collision_boxes(boxes: Array[Dictionary]) -> void:
	for child in get_children():
		if child is CollisionShape3D and child != collision_shape_3d:
			child.free()
			
	for box: Dictionary in boxes:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box["size"]
		
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.shape = shape
		shape_node.position = box["center"]
		
		add_child(shape_node)
		
	collision_shape_3d.disabled = true

#-###########################################
#              Mesh Commit
#-###########################################
func commit_mesh() -> void:
	mesh_data.commit()
	
	var array_mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
	array_mesh.clear_surfaces()
	
	if not mesh_data.is_empty():
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data.get_surface_array())
		mesh_instance.mesh.surface_set_material(0, material)
		
	apply_collision_boxes(pending_collision_boxes)

#-###########################################
#              Editing & Rebuild
#-###########################################
func set_voxel(position_index: Vector3i, voxel_type: TerrianData.TerrianType) -> void:
	chunk_data.add_voxel(position_index, voxel_type)
	add_provisional_collision(position_index)
	request_rebuild()


func remove_voxel_at_local(position_index: Vector3i) -> void:
	if chunk_data.get_voxel(position_index) == TerrianData.TerrianType.BEDROCK:
		return
	chunk_data.remove_voxel(position_index)
	request_rebuild()


func change_voxel_at_local(position_index: Vector3i, new_type: TerrianData.TerrianType) -> void:
	if chunk_data.get_voxel(position_index) == TerrianData.TerrianType.BEDROCK:
		return
	chunk_data.change_voxel(position_index, new_type)
	request_rebuild()


func add_provisional_collision(position_index: Vector3i) -> void:
	remove_provisional_collision()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE
	provisional_shape = CollisionShape3D.new()
	provisional_shape.shape = shape
	provisional_shape.position = Vector3(position_index)
	add_child(provisional_shape)


func remove_provisional_collision() -> void:
	if provisional_shape != null and is_instance_valid(provisional_shape):
		provisional_shape.free()
	provisional_shape = null


func request_rebuild() -> void:
	rebuild_mutex.lock()
	if rebuild_running:
		rebuild_dirty = true
		rebuild_mutex.unlock()
		return
	rebuild_running = true
	rebuild_mutex.unlock()
	
	active_task_id = WorkerThreadPool.add_task(rebuild_threaded, true, "chunk_edit_rebuild")


func rebuild_threaded() -> void:
	generate_mesh()
	compute_collision_boxes()
	call_deferred("_on_rebuild_complete")


func _on_rebuild_complete() -> void:
	if not is_instance_valid(self):
		return
		
	commit_mesh()
	
	rebuild_mutex.lock()
	var needs_another_pass: bool = rebuild_dirty
	rebuild_dirty = false
	if needs_another_pass:
		rebuild_mutex.unlock()
		active_task_id = WorkerThreadPool.add_task(rebuild_threaded, true, "chunk_edit_rebuild")
	else:
		rebuild_running = false
		active_task_id = -1
		rebuild_mutex.unlock()


func _exit_tree() -> void:
	if active_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(active_task_id)

#-###########################################
#              FaceAxes Class
#-###########################################
class FaceAxes:
	var normal_axis: int
	var normal_sign: int
	var across_axis: int
	var across_sign: int
	var up_axis: int
	var up_sign: int

	func _init(
		normal_axis_input: int,
		normal_sign_input: int,
		across_axis_input: int,
		across_sign_input: int,
		up_axis_input: int,
		up_sign_input: int
	) -> void:
		normal_axis = normal_axis_input
		normal_sign = normal_sign_input
		across_axis = across_axis_input
		across_sign = across_sign_input
		up_axis = up_axis_input
		up_sign = up_sign_input
