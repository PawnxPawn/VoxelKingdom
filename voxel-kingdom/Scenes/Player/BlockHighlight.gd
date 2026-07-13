#-###########################################
# Block Highlight Box
#-###########################################

extends MeshInstance3D

@export var line_color: Color = Color(0, 0, 0, 0.8)
@export var line_width: float = 0.02

var _surface_tool: SurfaceTool
var _material: StandardMaterial3D


#----------------
# Ready
#----------------
func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	
	material_override = _material
	hide()


#----------------
# Show Highlight
#----------------
func show_at_block(block_position: Vector3i, voxel_size: float = 1.0) -> void:
	var origin: Vector3 = (Vector3(block_position) - Vector3(0.5, 0.5, 0.5)) * voxel_size
	
	var corners: Array[Vector3] = [
		origin + Vector3(0, 0, 0),
		origin + Vector3(voxel_size, 0, 0),
		origin + Vector3(voxel_size, 0, voxel_size),
		origin + Vector3(0, 0, voxel_size),
		
		origin + Vector3(0, voxel_size, 0),
		origin + Vector3(voxel_size, voxel_size, 0),
		origin + Vector3(voxel_size, voxel_size, voxel_size),
		origin + Vector3(0, voxel_size, voxel_size),
	]
	
	var edges: Array[Array] = [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	
	_surface_tool = SurfaceTool.new()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_surface_tool.set_color(line_color)
	
	for edge in edges:
		var start_corner: Vector3 = corners[edge[0]]
		var end_corner: Vector3 = corners[edge[1]]
		_add_edge_box(start_corner, end_corner, line_width)
	
	mesh = _surface_tool.commit()
	show()


#----------------
# Hide Highlight
#----------------
func hide_highlight() -> void:
	hide()


#----------------
# Add Edge Box
#----------------
func _add_edge_box(start_point: Vector3, end_point: Vector3, thickness: float) -> void:
	var edge_direction: Vector3 = end_point - start_point
	var edge_length: float = edge_direction.length()
	
	if edge_length < 0.0001:
		return
	
	edge_direction = edge_direction / edge_length
	
	var reference_up: Vector3 = Vector3.UP
	if abs(edge_direction.dot(reference_up)) > 0.99:
		reference_up = Vector3.RIGHT
	
	var side_axis: Vector3 = edge_direction.cross(reference_up).normalized()
	var ortho_axis: Vector3 = edge_direction.cross(side_axis).normalized()
	
	var half_thickness: float = thickness * 0.5
	var side_offset: Vector3 = side_axis * half_thickness
	var ortho_offset: Vector3 = ortho_axis * half_thickness
	
	var box_corners: Array[Vector3] = [
		start_point - side_offset - ortho_offset,
		start_point + side_offset - ortho_offset,
		start_point + side_offset + ortho_offset,
		start_point - side_offset + ortho_offset,
		
		end_point - side_offset - ortho_offset,
		end_point + side_offset - ortho_offset,
		end_point + side_offset + ortho_offset,
		end_point - side_offset + ortho_offset,
	]
	
	var faces: Array[Array] = [
		[0, 1, 2, 3],
		[4, 7, 6, 5],
		[0, 4, 5, 1],
		[1, 5, 6, 2],
		[2, 6, 7, 3],
		[3, 7, 4, 0],
	]
	
	for face in faces:
		var a: Vector3 = box_corners[face[0]]
		var b: Vector3 = box_corners[face[1]]
		var c: Vector3 = box_corners[face[2]]
		var d: Vector3 = box_corners[face[3]]
		
		_surface_tool.add_vertex(a)
		_surface_tool.add_vertex(b)
		_surface_tool.add_vertex(c)
		
		_surface_tool.add_vertex(a)
		_surface_tool.add_vertex(c)
		_surface_tool.add_vertex(d)
