# BlockHighlight.gd
extends MeshInstance3D

@export var line_color: Color = Color(0, 0, 0, 0.8)
@export var line_width: float = 0.02

var _immediate_mesh: ImmediateMesh
var _material: StandardMaterial3D

func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()
	mesh = _immediate_mesh
	
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = false 
	material_override = _material
	
	hide()


func show_at_block(block_pos: Vector3i, voxel_size: float = 1.0) -> void:
	var origin: Vector3 = (Vector3(block_pos) - Vector3(0.5, 0.5, 0.5)) * voxel_size
	
	var corners: Array[Vector3] = [
		origin + Vector3(0, 0, 0), origin + Vector3(voxel_size, 0, 0),
		origin + Vector3(voxel_size, 0, voxel_size), origin + Vector3(0, 0, voxel_size),
		origin + Vector3(0, voxel_size, 0), origin + Vector3(voxel_size, voxel_size, 0),
		origin + Vector3(voxel_size, voxel_size, voxel_size), origin + Vector3(0, voxel_size, voxel_size),
	]
	
	var edges: Array[Array] = [
		[0,1],[1,2],[2,3],[3,0],  
		[4,5],[5,6],[6,7],[7,4],  
		[0,4],[1,5],[2,6],[3,7],  
	]
	
	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_immediate_mesh.surface_set_color(line_color)
	for e in edges:
		_immediate_mesh.surface_add_vertex(corners[e[0]])
		_immediate_mesh.surface_add_vertex(corners[e[1]])
	_immediate_mesh.surface_end()
	
	show()


func hide_highlight() -> void:
	hide()
