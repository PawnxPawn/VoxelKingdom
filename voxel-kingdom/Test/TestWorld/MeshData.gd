class_name MeshData extends Resource
var surface_array: Array = []
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var uvs: PackedVector2Array = PackedVector2Array()
var uv2s: PackedVector2Array = PackedVector2Array()
var number_of_vertices: int = 0

func _init() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)


func commit() -> void:
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_TEX_UV2] = uv2s


func add_data(vertex: Vector3, normal: Vector3, color: Color, uv: Vector2, uv2: Vector2) -> void:
	vertices.append(vertex)
	normals.append(normal)
	colors.append(color)
	uvs.append(uv)
	uv2s.append(uv2)
	number_of_vertices += 1


func is_empty() -> bool:
	return number_of_vertices <= 0


func get_surface_array() -> Array:
	return surface_array


func get_number_of_vertices() -> int:
	return number_of_vertices


func reset() -> void:
	surface_array.clear()
	vertices.clear()
	normals.clear()
	colors.clear()
	uvs.clear()
	uv2s.clear()
	number_of_vertices = 0
	surface_array.resize(Mesh.ARRAY_MAX)
