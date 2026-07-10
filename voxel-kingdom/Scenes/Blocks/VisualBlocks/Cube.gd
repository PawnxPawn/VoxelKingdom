class_name Cube extends MeshInstance3D

@export var block_type: TerrianData.TerrianType = TerrianData.TerrianType.DIRT
@export var atlas_columns: int = 3
@export var atlas_texture: Texture2D
@export var voxel_shader: Shader
@export var rotation_speed: float = 0.5  # radians/sec

var face_normals: Dictionary[Chunk.Face, Vector3] = {
	Chunk.Face.FRONT: Vector3(0, 0, 1),
	Chunk.Face.BACK: Vector3(0, 0, -1),
	Chunk.Face.LEFT: Vector3(-1, 0, 0),
	Chunk.Face.RIGHT: Vector3(1, 0, 0),
	Chunk.Face.BOTTOM: Vector3(0, -1, 0),
	Chunk.Face.TOP: Vector3(0, 1, 0),
}

var face_axes: Dictionary[Chunk.Face, Chunk.FaceAxes] = {
	Chunk.Face.FRONT: Chunk.FaceAxes.new(2, 1, 0, 1, 1, 1),
	Chunk.Face.BACK: Chunk.FaceAxes.new(2, -1, 0, -1, 1, 1),
	Chunk.Face.RIGHT: Chunk.FaceAxes.new(0, 1, 1, 1, 2, 1),
	Chunk.Face.LEFT: Chunk.FaceAxes.new(0, -1, 2, 1, 1, 1),
	Chunk.Face.TOP: Chunk.FaceAxes.new(1, 1, 2, 1, 0, 1),
	Chunk.Face.BOTTOM: Chunk.FaceAxes.new(1, -1, 0, 1, 2, 1),
}

var face_uv_rotation: Dictionary[Chunk.Face, int] = {
	Chunk.Face.FRONT: 2,
	Chunk.Face.BACK: 2,
	Chunk.Face.RIGHT: 1,
	Chunk.Face.LEFT: 2,
	Chunk.Face.TOP: 0,
	Chunk.Face.BOTTOM: 0,
}

func _ready() -> void:
	_build_cube()
	_apply_material()

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)

func _build_cube() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var atlas: BlockFaceAtlas = TerrianData.atlas_tiles[block_type]
	var tile_size: float = 1.0 / atlas_columns

	for face: Chunk.Face in Chunk.Face.values():
		_add_face(st, face, atlas, tile_size)

	st.generate_normals()
	mesh = st.commit()

func _add_face(st: SurfaceTool, face: Chunk.Face, atlas: BlockFaceAtlas, tile_size: float) -> void:
	var axes: Chunk.FaceAxes = face_axes[face]
	var normal: Vector3 = face_normals[face]

	var across_dir: Vector3 = Vector3.ZERO
	across_dir[axes.across_axis] = axes.across_sign
	var up_dir: Vector3 = Vector3.ZERO
	up_dir[axes.up_axis] = axes.up_sign

	var origin: Vector3 = Vector3.ZERO
	origin[axes.normal_axis] = 0.5 * axes.normal_sign
	origin[axes.across_axis] = -0.5 if axes.across_sign > 0 else 0.5
	origin[axes.up_axis] = -0.5 if axes.up_sign > 0 else 0.5

	var bottom_left: Vector3 = origin
	var top_left: Vector3 = bottom_left + up_dir
	var top_right: Vector3 = top_left + across_dir
	var bottom_right: Vector3 = bottom_left + across_dir

	var corners: Array[Vector3] = [bottom_left, top_left, top_right, bottom_left, top_right, bottom_right]

	var tile: Vector2i = _tile_for_face(face, atlas)
	var tile_origin: Vector2 = Vector2(tile.x, tile.y) * tile_size

	var u0: float = 1.0 if axes.across_sign < 0 else 0.0
	var u1: float = 0.0 if axes.across_sign < 0 else 1.0
	var v0: float = 1.0 if axes.up_sign < 0 else 0.0
	var v1: float = 0.0 if axes.up_sign < 0 else 1.0

	var rot: int = face_uv_rotation[face]
	var repeat_uvs: Array[Vector2] = [
		_face_uv(0, 0, u0, u1, v0, v1, rot),
		_face_uv(0, 1, u0, u1, v0, v1, rot),
		_face_uv(1, 1, u0, u1, v0, v1, rot),
		_face_uv(0, 0, u0, u1, v0, v1, rot),
		_face_uv(1, 1, u0, u1, v0, v1, rot),
		_face_uv(1, 0, u0, u1, v0, v1, rot),
	]

	for i in range(corners.size()):
		st.set_normal(normal)
		st.set_uv(repeat_uvs[i])
		st.set_uv2(tile_origin)
		st.add_vertex(corners[i])

func _face_uv(a: int, b: int, u0: float, u1: float, v0: float, v1: float, rotation_steps: int) -> Vector2:
	var k: int = ((rotation_steps % 4) + 4) % 4
	var p: int
	var q: int
	match k:
		0: p = a; q = b
		1: p = b; q = 1 - a
		2: p = 1 - a; q = 1 - b
		_: p = 1 - b; q = a

	if k % 2 == 0:
		return Vector2(u0 if p == 0 else u1, v0 if q == 0 else v1)
	else:
		return Vector2(v0 if p == 0 else v1, u0 if q == 0 else u1)

func _tile_for_face(face: Chunk.Face, atlas: BlockFaceAtlas) -> Vector2i:
	match face:
		Chunk.Face.TOP: return atlas.top
		Chunk.Face.BOTTOM: return atlas.bottom
		_: return atlas.side

func _apply_material() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = voxel_shader
	mat.set_shader_parameter("atlas_texture", atlas_texture)
	mat.set_shader_parameter("tile_size", 1.0 / atlas_columns)
	material_override = mat


func change_block_type(new_type: TerrianData.TerrianType) -> void:
	if new_type == block_type:
		return
	if not TerrianData.atlas_tiles.has(new_type):
		push_warning("No atlas entry for block type: %s" % TerrianData.TerrianType.keys()[new_type])
		return
	block_type = new_type
	_build_cube()
