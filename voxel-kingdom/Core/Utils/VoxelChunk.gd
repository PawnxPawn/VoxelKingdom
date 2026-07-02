class_name VoxelChunk
extends MeshInstance3D

var chunk_size: Vector3i = Vector3i(64, 64, 64)
var noise_scale: float = 0.05
var height_base: float = 8.0
var height_amplitude: float = 8.0

var cubes: int = 0
var voxel_data_array: PackedByteArray

const FACE_DEFINITIONS: Dictionary = {
	"top":    [Vector3(0, 1, 0), Vector3(0,1,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(0,1,1)],
	"bottom": [Vector3(0,-1, 0), Vector3(0,0,0), Vector3(0,0,1), Vector3(1,0,1), Vector3(1,0,0)],
	"right":  [Vector3(1, 0, 0), Vector3(1,0,0), Vector3(1,0,1), Vector3(1,1,1), Vector3(1,1,0)],
	"left":   [Vector3(-1,0, 0), Vector3(0,0,0), Vector3(0,1,0), Vector3(0,1,1), Vector3(0,0,1)],
	"front":  [Vector3(0, 0, 1), Vector3(0,0,1), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,0,1)],
	"back":   [Vector3(0, 0,-1), Vector3(0,0,0), Vector3(1,0,0), Vector3(1,1,0), Vector3(0,1,0)],
}


func _ready() -> void:
	generate_terrain()
	build_arraymesh_chunk()
	print("Blocks in world: %s" % cubes)


func _index(x: int, y: int, z: int) -> int:
	return x + z * chunk_size.x + y * chunk_size.x * chunk_size.z


func is_voxel_solid(x: int, y: int, z: int) -> bool:
	if x < 0 or x >= chunk_size.x: return false
	if y < 0 or y >= chunk_size.y: return false
	if z < 0 or z >= chunk_size.z: return false
	return voxel_data_array[_index(x, y, z)] == 1


func generate_terrain() -> void:
	var noise_generator := FastNoiseLite.new()
	noise_generator.frequency = noise_scale
	
	voxel_data_array.resize(chunk_size.x * chunk_size.y * chunk_size.z)
	
	for x in range(chunk_size.x):
		for z in range(chunk_size.z):
			var noise_value: float = noise_generator.get_noise_2d(x, z)
			var height_value: int = clampi(
				int(height_base + noise_value * height_amplitude),
				0,
				chunk_size.y - 1
			)
			
			for y in range(chunk_size.y):
				voxel_data_array[_index(x, y, z)] = 1 if y <= height_value else 0


func build_arraymesh_chunk() -> void:
	var vertex_positions := PackedVector3Array()
	var vertex_normals := PackedVector3Array()
	var vertex_indices := PackedInt32Array()
	
	var running_index: int = 0
	
	for x in range(chunk_size.x):
		for y in range(chunk_size.y):
			for z in range(chunk_size.z):
				if not is_voxel_solid(x, y, z):
					continue
					
				var voxel_position := Vector3(x, y, z)
				_add_visible_faces_to_arrays(
					voxel_position,
					vertex_positions,
					vertex_normals,
					vertex_indices,
					running_index
				)
				
				running_index = vertex_positions.size()
				cubes += 1
	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertex_positions
	mesh_arrays[Mesh.ARRAY_NORMAL] = vertex_normals
	mesh_arrays[Mesh.ARRAY_INDEX] = vertex_indices
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	
	mesh = array_mesh
	create_trimesh_collision()


func _add_visible_faces_to_arrays( voxel_position: Vector3, vertex_positions: Array, vertex_normals: Array, vertex_indices: Array, running_index: int ) -> void:
	
	var vx: int = int(voxel_position.x)
	var vy: int = int(voxel_position.y)
	var vz: int = int(voxel_position.z)
	
	if not is_voxel_solid(vx, vy + 1, vz):
		_add_face_arrays("top", voxel_position, vertex_positions, vertex_normals, vertex_indices, running_index)
	
	if not is_voxel_solid(vx, vy - 1, vz):
		_add_face_arrays("bottom", voxel_position, vertex_positions, vertex_normals, vertex_indices, running_index)
	
	if not is_voxel_solid(vx + 1, vy, vz):
		_add_face_arrays("right", voxel_position, vertex_positions, vertex_normals, vertex_indices, running_index)
	
	if not is_voxel_solid(vx - 1, vy, vz):
		_add_face_arrays("left", voxel_position, vertex_positions, vertex_normals, vertex_indices, running_index)
	
	if not is_voxel_solid(vx, vy, vz + 1):
		_add_face_arrays("front", voxel_position, vertex_positions, vertex_normals, vertex_indices, running_index)
	
	if not is_voxel_solid(vx, vy, vz - 1):
		_add_face_arrays("back", voxel_position, vertex_positions, vertex_normals, vertex_indices, running_index)


func _add_face_arrays(
	face_name: String,
	voxel_position: Vector3,
	vertex_positions: PackedVector3Array,
	vertex_normals: PackedVector3Array,
	vertex_indices: PackedInt32Array,
	running_index: int
) -> void:

	var face_definition: Array = FACE_DEFINITIONS[face_name]
	var face_normal: Vector3 = face_definition[0]

	var corner_offset_0: Vector3 = face_definition[1]
	var corner_offset_1: Vector3 = face_definition[2]
	var corner_offset_2: Vector3 = face_definition[3]
	var corner_offset_3: Vector3 = face_definition[4]

	var world_vertex_0: Vector3 = voxel_position + corner_offset_0
	var world_vertex_1: Vector3 = voxel_position + corner_offset_1
	var world_vertex_2: Vector3 = voxel_position + corner_offset_2
	var world_vertex_3: Vector3 = voxel_position + corner_offset_3

	vertex_positions.append(world_vertex_0)
	vertex_positions.append(world_vertex_1)
	vertex_positions.append(world_vertex_2)
	vertex_positions.append(world_vertex_3)

	vertex_normals.append(face_normal)
	vertex_normals.append(face_normal)
	vertex_normals.append(face_normal)
	vertex_normals.append(face_normal)

	vertex_indices.append(running_index + 0)
	vertex_indices.append(running_index + 1)
	vertex_indices.append(running_index + 2)

	vertex_indices.append(running_index + 0)
	vertex_indices.append(running_index + 2)
	vertex_indices.append(running_index + 3)
