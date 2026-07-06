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
@export var stone_height: int = 45
@export var dirt_depth: int = 3      
@export var bedrock_height: int = 2


@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

static var cube_count: int = 0

var chunk_data: ChunkData = ChunkData.new()
var voxel_colors: Dictionary[TerrianData.TerrianType, Color] = {}
var chunk_size: int = 0

var mesh_data: MeshData = MeshData.new()
var collision_faces: PackedVector3Array = PackedVector3Array()
var _pending_collision_boxes: Array[Dictionary] = []

var _rebuild_mutex: Mutex = Mutex.new()
var _rebuild_running: bool = false
var _rebuild_dirty: bool = false
var _active_task_id: int = -1

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

var _provisional_shape: CollisionShape3D = null

func _ready() -> void:
	mesh_instance.mesh = ArrayMesh.new()
	collision_shape_3d.disabled = true
	if chunk_data.is_empty():
		return
	commit_mesh()


func generate_date(size: int, max_height: int, noise: Noise, color_array: Dictionary[TerrianData.TerrianType, Color]) -> void:
	chunk_size = size
	chunk_data.set_size(size)
	voxel_colors = color_array
	
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
				var depth_from_surface: int = int(local_height) - 1 - y
				var terrain_type: TerrianData.TerrianType
				var global_y: int = int(position.y) + y
				
				if global_y <= bedrock_height:
					terrain_type = TerrianData.TerrianType.BEDROCK
				elif global_y >= stone_height:
					terrain_type = TerrianData.TerrianType.STONE
				elif depth_from_surface == 0:
					terrain_type = TerrianData.TerrianType.GRASS
				elif depth_from_surface <= dirt_depth:
					terrain_type = TerrianData.TerrianType.DIRT
				else:
					terrain_type = TerrianData.TerrianType.STONE
				
				chunk_data.add_voxel(Vector3i(x, y, z), terrain_type)
				cube_count += 1


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
				var pos: Vector3i = Vector3i.ZERO
				pos[axes.normal_axis] = layer
				pos[axes.across_axis] = across
				pos[axes.up_axis] = up
				
				var voxel: int = flat_voxels[pos.x + pos.z * chunk_size + pos.y * chunk_size * chunk_size]
				if voxel == TerrianData.TerrianType.AIR:
					continue
				
				var neighbor: Vector3i = pos + Vector3i(normal)
				var mask_index: int = across * chunk_size + up
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.z < 0 or neighbor.x >= chunk_size or neighbor.y >= chunk_size or neighbor.z >= chunk_size:
					mask[mask_index] = voxel
					continue
				
				var neighbor_voxel: int = flat_voxels[neighbor.x + neighbor.z * chunk_size + neighbor.y * chunk_size * chunk_size]
				if neighbor_voxel != TerrianData.TerrianType.AIR:
					continue
				
				mask[mask_index] = voxel
				
		merge_mask(mask, face, axes, layer)


func merge_mask(mask: PackedInt32Array, face: Face, axes: FaceAxes, layer: int) -> void:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(chunk_size * chunk_size)
	
	for across: int in range(chunk_size):
		for up: int in range(chunk_size):
			var start_index: int = across * chunk_size + up
			if visited[start_index] or mask[start_index] == -1:
				continue
			
			var voxel: int = mask[start_index]
			var width: int = 1
			while across + width < chunk_size:
				var next_index: int = (across + width) * chunk_size + up
				if mask[next_index] != voxel or visited[next_index]:
					break
				width += 1
			
			var height: int = 1
			while up + height < chunk_size:
				var row_matches: bool = true
				for dx: int in range(width):
					var cell_index: int = (across + dx) * chunk_size + (up + height)
					if mask[cell_index] != voxel or visited[cell_index]:
						row_matches = false
						break
				if not row_matches:
					break
				height += 1
				
			for dx: int in range(width):
				for dy: int in range(height):
					visited[(across + dx) * chunk_size + (up + dy)] = 1
					
			add_quad(face, axes, layer, across, up, width, height, voxel_colors[voxel as TerrianData.TerrianType])


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
		mesh_data.add_data(corner, normal, color)
		collision_faces.append(corner)


func compute_collision_boxes() -> void:
	if chunk_data.is_empty():
		_pending_collision_boxes = []
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
				
				var size: Vector3 = Vector3(max_x - x + 1, max_y - y + 1, max_z - z + 1)
				var center: Vector3 = Vector3(
					x + size.x * 0.5 - 0.5,
					y + size.y * 0.5 - 0.5,
					z + size.z * 0.5 - 0.5
				)
				
				boxes.append({"size": size, "center": center})
	
	_pending_collision_boxes = boxes


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


func commit_mesh() -> void:
	mesh_data.commit()
	
	var arr_mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
	arr_mesh.clear_surfaces()
	if not mesh_data.is_empty():
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data.get_surface_array())
		mesh_instance.mesh.surface_set_material(0, material)
	
	apply_collision_boxes(_pending_collision_boxes)


func set_voxel(pos: Vector3i, voxel: TerrianData.TerrianType) -> void:
	chunk_data.add_voxel(pos, voxel)
	_add_provisional_collision(pos)
	_request_rebuild()


func remove_voxel_at_local(pos: Vector3i) -> void:
	chunk_data.remove_voxel(pos)
	_request_rebuild()


func _add_provisional_collision(pos: Vector3i) -> void:
	_remove_provisional_collision()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE
	_provisional_shape = CollisionShape3D.new()
	_provisional_shape.shape = shape
	_provisional_shape.position = Vector3(pos)
	add_child(_provisional_shape)


func _remove_provisional_collision() -> void:
	if _provisional_shape != null and is_instance_valid(_provisional_shape):
		_provisional_shape.free()
	_provisional_shape = null


func _request_rebuild() -> void:
	_rebuild_mutex.lock()
	if _rebuild_running:
		_rebuild_dirty = true
		_rebuild_mutex.unlock()
		return
	_rebuild_running = true
	_rebuild_mutex.unlock()
	
	_active_task_id = WorkerThreadPool.add_task(_rebuild_threaded, true, "chunk_edit_rebuild")


func _rebuild_threaded() -> void:
	generate_mesh()
	compute_collision_boxes()
	call_deferred("_on_rebuild_complete")


func _on_rebuild_complete() -> void:
	if not is_instance_valid(self):
		return
	
	commit_mesh()
	
	_rebuild_mutex.lock()
	var needs_another_pass: bool = _rebuild_dirty
	_rebuild_dirty = false
	if needs_another_pass:
		_rebuild_mutex.unlock()
		_active_task_id = WorkerThreadPool.add_task(_rebuild_threaded)
	else:
		_rebuild_running = false
		_active_task_id = -1
		_rebuild_mutex.unlock()


func _exit_tree() -> void:
	if _active_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_active_task_id)


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
