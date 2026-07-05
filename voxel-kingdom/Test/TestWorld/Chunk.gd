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
var chunk_size: int = 0

var surface_array: Array = []
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var collision_faces: PackedVector3Array = PackedVector3Array()

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



func _ready() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)
	mesh_instance.mesh = ArrayMesh.new()
	collision_shape_3d.disabled = true
	if voxels.is_empty():
		return
	commit_mesh()


func generate_date(size: int, max_height: int, noise: Noise, color_array: Array[Color]) -> void:
	chunk_size = size
	
	for x: int in range(size):
		for z: int in range(size):
			var global_pos: Vector3 = position + Vector3(x, 0, z)
			var noise_sum: float = (
				noise.get_noise_2d(global_pos.x, global_pos.z) +
				0.5 * noise.get_noise_2d(global_pos.x * 2, global_pos.z * 2) +
				0.25 * noise.get_noise_2d(global_pos.x * 4, global_pos.z * 4)
			)
			var noise_value: float = (noise_sum / 1.75 + 1.0) / 2.0
			var height_curve: float = pow(noise_value, 2.1)
			var target_height: float = max_height * height_curve
			
			if target_height < position.y:
				continue
			
			var local_height: float = target_height - position.y
			
			for y: int in range(min(local_height, size)):
				var depth_from_surface: int = int(local_height) - y
				var color_index: int = min(depth_from_surface, color_array.size() - 1)
				voxels[Vector3(x, y, z)] = color_array[color_index]
				cube_count += 1


func generate_mesh() -> void:
	if voxels.is_empty():
		return
	for face: Face in Face.values():
		mesh_face(face)


func mesh_face(face: Face) -> void:
	var axes: FaceAxes = face_axes[face]
	var normal: Vector3 = face_normals[face]
	
	for layer: int in range(chunk_size):
		var mask: Dictionary[Vector2i, Color] = {}
		
		for across: int in range(chunk_size):
			for up: int in range(chunk_size):
				var pos: Vector3 = Vector3.ZERO
				pos[axes.normal_axis] = layer
				pos[axes.across_axis] = across
				pos[axes.up_axis] = up
				
				if not voxels.has(pos):
					continue
				
				var neighbor: Vector3 = pos + normal
				if voxels.has(neighbor):
					continue 
				
				mask[Vector2i(across, up)] = voxels[pos]
				
		merge_mask(mask, face, axes, layer)


func merge_mask(mask: Dictionary[Vector2i, Color], face: Face, axes: FaceAxes, layer: int) -> void:
	var visited: Dictionary[Vector2i, bool] = {}
	
	for across: int in range(chunk_size):
		for up: int in range(chunk_size):
			var start: Vector2i = Vector2i(across, up)
			if visited.has(start) or not mask.has(start):
				continue
			
			var color: Color = mask[start]
			var width: int = 1
			while across + width < chunk_size:
				var next_cell: Vector2i = Vector2i(across + width, up)
				if mask.get(next_cell) != color or visited.has(next_cell):
					break
				width += 1
			
			var height: int = 1
			while up + height < chunk_size:
				var row_matches: bool = true
				for dx: int in range(width):
					var cell: Vector2i = Vector2i(across + dx, up + height)
					if mask.get(cell) != color or visited.has(cell):
						row_matches = false
						break
				if not row_matches:
					break
				height += 1
				
			for dx: int in range(width):
				for dy: int in range(height):
					visited[Vector2i(across + dx, up + dy)] = true
					
			add_quad(face, axes, layer, across, up, width, height, color)


func add_quad(face: Face, axes: FaceAxes, layer: int, across: int, up: int, width: int, height: int, color: Color) -> void:
	var across_dir: Vector3 = Vector3.ZERO
	across_dir[axes.across_axis] = axes.across_sign
	var up_dir: Vector3 = Vector3.ZERO
	up_dir[axes.up_axis] = axes.up_sign
	
	var origin: Vector3 = Vector3.ZERO
	origin[axes.normal_axis] = layer + 0.5 * axes.normal_sign
	origin[axes.across_axis] = (across - 0.5) if axes.across_sign > 0 else (across + width - 0.5)
	origin[axes.up_axis] = (up - 0.5) if axes.up_sign > 0 else (up + height - 0.5)
	
	var bottom_left: Vector3 = origin
	var top_left: Vector3 = bottom_left + up_dir * height
	var top_right: Vector3 = top_left + across_dir * width
	var bottom_right: Vector3 = bottom_left + across_dir * width
	
	var normal: Vector3 = face_normals[face]
	var corners: Array[Vector3] = [bottom_left, top_left, top_right, bottom_left, top_right, bottom_right]
	
	for corner: Vector3 in corners:
		vertices.append(corner)
		normals.append(normal)
		colors.append(color)
		collision_faces.append(corner)


func commit_mesh() -> void:
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	
	var arr_mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	mesh_instance.mesh.surface_set_material(0, material)
	
	generate_collision()


func generate_collision() -> void:
	var visited: Dictionary[Vector3, bool] = {}
	var boxes: Array[Dictionary] = []
	
	for x: int in range(chunk_size):
		for y: int in range(chunk_size):
			for z: int in range(chunk_size):
				var start: Vector3 = Vector3(x, y, z)
				
				if not voxels.has(start) or visited.has(start):
					continue
					
				var max_x: int = x
				while max_x + 1 < chunk_size and voxels.has(Vector3(max_x + 1, y, z)):
					max_x += 1
					
				var max_z: int = z
				var can_grow_z: bool = true
				while can_grow_z and max_z + 1 < chunk_size:
					for scan_x: int in range(x, max_x + 1):
						if not voxels.has(Vector3(scan_x, y, max_z + 1)):
							can_grow_z = false
							break
					if can_grow_z:
						max_z += 1
						
				var max_y: int = y
				var can_grow_y: bool = true
				while can_grow_y and max_y + 1 < chunk_size:
					for scan_x: int in range(x, max_x + 1):
						for scan_z: int in range(z, max_z + 1):
							if not voxels.has(Vector3(scan_x, max_y + 1, scan_z)):
								can_grow_y = false
								break
						if not can_grow_y:
							break
					if can_grow_y:
						max_y += 1
						
				for scan_x: int in range(x, max_x + 1):
					for scan_y: int in range(y, max_y + 1):
						for scan_z: int in range(z, max_z + 1):
							visited[Vector3(scan_x, scan_y, scan_z)] = true
							
				var size: Vector3 = Vector3(max_x - x + 1, max_y - y + 1, max_z - z + 1)
				var center: Vector3 = Vector3(
					x + size.x * 0.5 - 0.5,
					y + size.y * 0.5 - 0.5,
					z + size.z * 0.5 - 0.5
				)
				
				boxes.append({"size": size, "center": center})
				
	apply_collision_boxes(boxes)


func apply_collision_boxes(boxes: Array[Dictionary]) -> void:
	for box: Dictionary in boxes:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box["size"]
		
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.shape = shape
		shape_node.position = box["center"]
		
		add_child(shape_node)
		
	print("collision boxes: ", boxes.size())
	collision_shape_3d.disabled = true


#=============================================
#              FaceAxes Class
#=============================================
class FaceAxes:
	var normal_axis: int
	var normal_sign: int
	var across_axis: int
	var across_sign: int
	var up_axis: int
	var up_sign: int

	func _init(p_normal_axis: int, p_normal_sign: int, p_across_axis: int, p_across_sign: int, p_up_axis: int, p_up_sign: int) -> void:
		normal_axis = p_normal_axis
		normal_sign = p_normal_sign
		across_axis = p_across_axis
		across_sign = p_across_sign
		up_axis = p_up_axis
		up_sign = p_up_sign
