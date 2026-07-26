class_name BreakParticles
extends GPUParticles3D

@export var block_type: TerrianData.TerrianType = TerrianData.TerrianType.DIRT
@export var atlas_columns: int = 4
@export var atlas_texture: Texture2D
@export var voxel_shader: Shader
@export var shard_count: int = 12
@export var shard_lifetime: float = 0.45
@export var shard_speed: float = 4.0

var face_normals: Dictionary = {
	Chunk.Face.FRONT: Vector3(0, 0, 1), 
	Chunk.Face.BACK: Vector3(0, 0, -1), 
	Chunk.Face.LEFT: Vector3(-1, 0, 0), 
	Chunk.Face.RIGHT: Vector3(1, 0, 0), 
	Chunk.Face.BOTTOM: Vector3(0, -1, 0), 
	Chunk.Face.TOP: Vector3(0, 1, 0), 
}

var face_axes: Dictionary = {
	Chunk.Face.FRONT: Chunk.FaceAxes.new(2, 1, 0, 1, 1, 1), 
	Chunk.Face.BACK: Chunk.FaceAxes.new(2, -1, 0, -1, 1, 1), 
	Chunk.Face.RIGHT: Chunk.FaceAxes.new(0, 1, 1, 1, 2, 1), 
	Chunk.Face.LEFT: Chunk.FaceAxes.new(0, -1, 2, 1, 1, 1), 
	Chunk.Face.TOP: Chunk.FaceAxes.new(1, 1, 2, 1, 0, 1), 
	Chunk.Face.BOTTOM: Chunk.FaceAxes.new(1, -1, 0, 1, 2, 1), 
}

var face_uv_rotation: Dictionary = {
	Chunk.Face.FRONT: 2, 
	Chunk.Face.BACK: 2, 
	Chunk.Face.RIGHT: 1, 
	Chunk.Face.LEFT: 2, 
	Chunk.Face.TOP: 0, 
	Chunk.Face.BOTTOM: 0, 
}


var cube_mesh: Mesh
var base_material: ShaderMaterial


func _build_cube() -> void :
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var atlas: BlockFaceAtlas = TerrianData.atlas_tiles[block_type]
	var tile_size: float = 1.0 / atlas_columns

	for face: Chunk.Face in Chunk.Face.values():
		_add_face(st, face, atlas, tile_size)

	st.generate_normals()
	cube_mesh = st.commit()


func _build_material() -> void :
	var mat: = ShaderMaterial.new()
	mat.shader = voxel_shader
	mat.set_shader_parameter("atlas_texture", atlas_texture)
	mat.set_shader_parameter("tile_size", 1.0 / atlas_columns)
	base_material = mat


func emit_at(world_pos: Vector3, new_type: TerrianData.TerrianType) -> void :
	block_type = new_type
	_build_cube()
	_build_material()
	global_position = world_pos

	var atlas: BlockFaceAtlas = TerrianData.atlas_tiles[new_type]
	var tile: Vector2i = atlas.side

	var tile_size: float = 1.0 / atlas_columns
	var tile_origin: = Vector2(
		float(tile.x) * tile_size, 
		float(tile.y) * tile_size
	)

	for i in shard_count:
		_spawn_shard(tile_origin)


func _spawn_shard(tile_origin: Vector2) -> void :
	var shard: = RigidBody3D.new()
	shard.freeze = false
	shard.gravity_scale = 1.0
	shard.mass = 0.05
	shard.collision_layer = 1 << 2
	shard.collision_mask = 1 << 0

	var mi: = MeshInstance3D.new()
	mi.mesh = cube_mesh
	mi.scale = Vector3(randf_range(0.05, 0.15), randf_range(0.05, 0.15), randf_range(0.05, 0.15))

	var mat: = base_material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("tile_origin", tile_origin)
	mi.material_override = mat

	shard.add_child(mi)

	var collider: = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(0.1, 0.1, 0.1)
	shard.add_child(collider)

	add_child(shard)

	var velocity: = Vector3(
		randf_range(-1.5, 1.5), 
		randf_range(0.5, 1.2), 
		randf_range(-1.5, 1.5)
	)

	velocity.y -= randf_range(1.5, 3.0)

	shard.linear_velocity = velocity * shard_speed


	var tween: = create_tween()
	tween.tween_property(mi, "scale", Vector3.ZERO, shard_lifetime)
	tween.finished.connect( func(): shard.queue_free())


func _add_face(
		st: SurfaceTool, 
		face: Chunk.Face, 
		atlas: BlockFaceAtlas, 
		tile_size: float
	) -> void :

	var axes: Chunk.FaceAxes = face_axes[face]
	var normal: Vector3 = face_normals[face]

	var across_dir: = Vector3.ZERO
	across_dir[axes.across_axis] = axes.across_sign

	var up_dir: = Vector3.ZERO
	up_dir[axes.up_axis] = axes.up_sign

	var origin: = Vector3.ZERO
	origin[axes.normal_axis] = 0.5 * axes.normal_sign
	origin[axes.across_axis] = -0.5 if axes.across_sign > 0 else 0.5
	origin[axes.up_axis] = -0.5 if axes.up_sign > 0 else 0.5

	var bottom_left: = origin
	var top_left: = bottom_left + up_dir
	var top_right: = top_left + across_dir
	var bottom_right: = bottom_left + across_dir

	var corners: Array[Vector3] = [
		bottom_left, top_left, top_right, 
		bottom_left, top_right, bottom_right
	]

	var tile: Vector2i = _tile_for_face(face, atlas)
	var tile_origin: = Vector2(tile.x, tile.y) * tile_size

	var u0: = 1.0 if axes.across_sign < 0 else 0.0
	var u1: = 0.0 if axes.across_sign < 0 else 1.0
	var v0: = 1.0 if axes.up_sign < 0 else 0.0
	var v1: = 0.0 if axes.up_sign < 0 else 1.0

	var rot: int = face_uv_rotation[face]

	var repeat_uvs: Array[Vector2] = [
		_face_uv(0, 0, u0, u1, v0, v1, rot), 
		_face_uv(0, 1, u0, u1, v0, v1, rot), 
		_face_uv(1, 1, u0, u1, v0, v1, rot), 
		_face_uv(0, 0, u0, u1, v0, v1, rot), 
		_face_uv(1, 1, u0, u1, v0, v1, rot), 
		_face_uv(1, 0, u0, u1, v0, v1, rot), 
	]

	for i in corners.size():
		st.set_normal(normal)
		st.set_uv(repeat_uvs[i])
		st.set_uv2(tile_origin)
		st.add_vertex(corners[i])

func _face_uv(
		a: int, 
		b: int, 
		u0: float, 
		u1: float, 
		v0: float, 
		v1: float, 
		rotation_steps: int
	) -> Vector2:

	var rotation_index: = ((rotation_steps % 4) + 4) % 4

	var rotated_u: int
	var rotated_v: int

	match rotation_index:
		0:
			rotated_u = a
			rotated_v = b
		1:
			rotated_u = b
			rotated_v = 1 - a
		2:
			rotated_u = 1 - a
			rotated_v = 1 - b
		_:
			rotated_u = 1 - b
			rotated_v = a

	if rotation_index % 2 == 0:
		return Vector2(
			u0 if rotated_u == 0 else u1, 
			v0 if rotated_v == 0 else v1
		)
	else:
		return Vector2(
			v0 if rotated_u == 0 else v1, 
			u0 if rotated_v == 0 else u1
		)


func _tile_for_face(face: Chunk.Face, atlas: BlockFaceAtlas) -> Vector2i:
	match face:
		Chunk.Face.TOP:
			return atlas.top
		Chunk.Face.BOTTOM:
			return atlas.bottom
		_:
			return atlas.side
