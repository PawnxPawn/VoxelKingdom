extends MeshInstance3D

@export var material: Material

enum Face {
	BOTTOM,
	FRONT,
	RIGHT,
	TOP,
	LEFT,
	BACK,
}


var surface_array: Array = []
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()

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


func _ready() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)


func generate_mesh(data: Dictionary[Vector3, Color]) -> void:
	for pos in data:
		for face in Face.values():
			if has_neighbor(data, face , pos): continue
			var color = data[pos]
			add_face(face, pos, color)
	commit_mesh()


func add_face(face: Face, pos: Vector3, color: Color) -> void:
	var indices = face_indices[face]
	for triangle in indices:
		for index in triangle:
			vertices.append(cube_vertices[index] + pos)
			normals.append(face_normals[face])
			colors.append(color)


func has_neighbor(data: Dictionary[Vector3, Color], face: Face, pos: Vector3) -> bool:
	var neighbor_pos = pos + face_normals[face]
	if data.has(neighbor_pos): return true
	return false


func commit_mesh() -> void:
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	
	
	var arr_mesh: ArrayMesh = mesh as ArrayMesh
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	mesh.surface_set_material(0, material)
