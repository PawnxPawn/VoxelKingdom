class_name Chunk extends StaticBody3D


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

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

static var cube_count: int = 0

var voxels: Dictionary[Vector3, Color] = {}

var surface_array: Array = []
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var collision_faces: PackedVector3Array = PackedVector3Array()


var cube_vertices: Array[Vector3] = [
	Vector3(-0.5, -0.5, 0.5),
	Vector3(0.5, -0.5, 0.5),
	Vector3(0.5, -0.5, -0.5),
	Vector3(-0.5, -0.5, -0.5),
	Vector3(-0.5, 0.5, 0.5),
	Vector3(0.5, 0.5, 0.5),
	Vector3(0.5, 0.5, -0.5),
	Vector3(-0.5, 0.5, -0.5),
]

var face_indices: Dictionary[Face, Array] = {
	Face.FRONT: [[0, 4, 5],[0, 5, 1]],
	Face.BACK: [[2, 7, 3],[2, 6, 7]],
	Face.LEFT: [[3, 7, 4],[3, 4, 0]],
	Face.RIGHT: [[1, 5, 6],[1, 6, 2]],
	Face.BOTTOM: [[0, 1, 2],[0, 2, 3]],
	Face.TOP: [[4, 7, 6],[4, 6, 5]],
}

var face_normals: Dictionary[Face, Vector3] = {
	Face.FRONT: Vector3(0,0,1),
	Face.BACK: Vector3(0,0,-1),
	Face.LEFT: Vector3(-1,0,0),
	Face.RIGHT: Vector3(1,0,0),
	Face.BOTTOM: Vector3(0,-1,0),
	Face.TOP: Vector3(0,1,0),
}

var face_colors: Dictionary[Face, Color] = {
	Face.FRONT: Color.ORANGE,
	Face.BACK: Color.PURPLE,
	Face.LEFT: Color.BLUE,
	Face.RIGHT: Color.YELLOW,
	Face.BOTTOM: Color.RED,
	Face.TOP: Color.GREEN,
}

var chunk:int = 0

func _ready() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)
	mesh_instance.mesh = ArrayMesh.new()
	collision_shape_3d.disabled = true
	if voxels.is_empty(): return
	commit_mesh()


func generate_date(chunk_size: int, max_height: int, noise: Noise, color_array: Array[Color]) -> void:
	chunk = chunk_size
	for x in range(chunk_size):
		for z in range(chunk_size):
			var global_pos = position + Vector3(x, 0, z)
			var sum: float = (
				noise.get_noise_2d(global_pos.x, global_pos.z) +
				0.5 * noise.get_noise_2d(global_pos.x * 2, global_pos.z * 2) +
				0.25 * noise.get_noise_2d(global_pos.x * 4, global_pos.z * 4)
			)
			var rand: float = (sum / 1.75 + 1.0) / 2.0
			var rand_p = pow(rand, 2.1)
			var height = max_height * rand_p

			if height < position.y: continue

			var local_height = height - position.y
			for y in range(min(local_height, chunk_size)):
				voxels[Vector3(x, y, z)] = color_array[y % color_array.size()]
				cube_count += 1

#Player position / cell_size floor. ChunckManager.Chunk.Voxel[player_pos]. 

func generate_mesh() -> void:
	if voxels.is_empty(): return
	
	for pos in voxels:
		for face in Face.values():
			if has_neighbor(voxels, face , pos): continue
			var color = voxels[pos]
			add_face(face, pos, color)


func add_face(face: Face, pos: Vector3, color: Color) -> void:
	var indices = face_indices[face]
	for triangle in indices:
		for index in triangle:
			var vert = cube_vertices[index] + pos
			vertices.append(vert)
			normals.append(face_normals[face])
			colors.append(color)
			collision_faces.append(vert)


func has_neighbor(data: Dictionary[Vector3, Color], face: Face, pos: Vector3) -> bool:
	var neighbor_pos = pos + face_normals[face]
	if data.has(neighbor_pos): return true
	return false


func commit_mesh() -> void:
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	
	
	var arr_mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	mesh_instance.mesh.surface_set_material(0, material)
	
	generate_greedy_collision(chunk)
	
	#if collision_faces.size() > 0:
		#var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		#shape.set_faces(collision_faces)
		#collision_shape_3d.shape = shape
		#collision_shape_3d.disabled = false

func generate_greedy_collision(chunk_size: int) -> void:
	var visited_voxels: Dictionary = {}
	var merged_collision_shapes: Array = []
	
	for x: int in range(chunk_size):
		for y: int in range(chunk_size):
			for z: int in range(chunk_size):
				var voxel_position: Vector3 = Vector3(x, y, z)
				
				if !voxels.has(voxel_position):
					continue
				if visited_voxels.has(voxel_position):
					continue
					
				var maximum_x: int = x
				var maximum_y: int = y
				var maximum_z: int = z
				
				while maximum_x + 1 < chunk_size and voxels.has(Vector3(maximum_x + 1, y, z)):
					maximum_x += 1
					
				var can_expand_z: bool = true
				while can_expand_z and maximum_z + 1 < chunk_size:
					for expanded_x: int in range(x, maximum_x + 1):
						if !voxels.has(Vector3(expanded_x, y, maximum_z + 1)):
							can_expand_z = false
							break
					if can_expand_z:
						maximum_z += 1
						
				var can_expand_y: bool = true
				while can_expand_y and maximum_y + 1 < chunk_size:
					for expanded_x: int in range(x, maximum_x + 1):
						for expanded_z: int in range(z, maximum_z + 1):
							if !voxels.has(Vector3(expanded_x, maximum_y + 1, expanded_z)):
								can_expand_y = false
								break
						if !can_expand_y:
							break
					if can_expand_y:
						maximum_y += 1
						
				for expanded_x: int in range(x, maximum_x + 1):
					for expanded_y: int in range(y, maximum_y + 1):
						for expanded_z: int in range(z, maximum_z + 1):
							visited_voxels[Vector3(expanded_x, expanded_y, expanded_z)] = true
							
				var region_size: Vector3 = Vector3(
					maximum_x - x + 1,
					maximum_y - y + 1,
					maximum_z - z + 1
				)
				
				var region_center: Vector3 = Vector3(
					x + region_size.x * 0.5 - 0.5,
					y + region_size.y * 0.5 - 0.5,
					z + region_size.z * 0.5 - 0.5
				)
				
				merged_collision_shapes.append({
					"size": region_size,
					"center": region_center
				})
				
	var collision_root: Node3D = Node3D.new()
	collision_root.name = "MergedCollision"
	add_child(collision_root)
	
	apply_collision_shapes(merged_collision_shapes)

func apply_collision_shapes(merged_collision_shapes: Array) -> void:
	for shape_data: Dictionary in merged_collision_shapes:
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = shape_data["size"]
		
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		collision_shape.shape = box_shape
		collision_shape.position = shape_data["center"]
		
		self.add_child(collision_shape)
	
	var box_count := merged_collision_shapes.size()
	var triangle_count := box_count * 12
	print("collision triangles: ", triangle_count)
	collision_shape_3d.disabled = true
