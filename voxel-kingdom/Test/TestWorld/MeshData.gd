class_name MeshData
extends Resource

var surface_array: Array = []
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var number_of_vertices: int = 0


func _init() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)


func commit() -> void:
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors


func add_data(vertex: Vector3, normal: Vector3, color: Color) -> void:
	vertices.append(vertex)
	normals.append(normal)
	colors.append(color)
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
	number_of_vertices = 0
	surface_array.resize(Mesh.ARRAY_MAX)
