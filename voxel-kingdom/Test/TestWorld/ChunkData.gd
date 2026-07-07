class_name ChunkData extends Resource

var voxels: PackedInt32Array
var chunk_size: int = 32
var voxel_amount:int = 0

func _init() -> void:
	set_size(chunk_size)


func set_size(size: int) -> void:
	chunk_size = size
	
	voxels = PackedInt32Array()
	voxels.resize(size * size * size)
	voxels.fill(TerrianData.TerrianType.AIR)
	voxel_amount = 0


func add_voxel(pos: Vector3i, voxel_type: TerrianData.TerrianType) -> void:
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or  pos.x >= chunk_size or pos.y >= chunk_size or pos.z >= chunk_size:
		return
	voxels[_position_to_index(pos)] = voxel_type
	if voxel_type != TerrianData.TerrianType.AIR:
		voxel_amount += 1


func remove_voxel(pos: Vector3i) -> void:
	var voxel: int = get_voxel(pos)
	if voxel == TerrianData.TerrianType.AIR:
		return
	voxels[_position_to_index(pos)] = TerrianData.TerrianType.AIR
	voxel_amount -= 1


func get_number_of_voxels() -> int:
	return voxel_amount


func is_empty() -> bool:
	return voxel_amount <= 0


func get_voxels_copy() -> PackedInt32Array:
	return voxels


func get_voxel(pos: Vector3i) -> TerrianData.TerrianType:
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or pos.x >= chunk_size or pos.y >= chunk_size or pos.z >= chunk_size:
		return TerrianData.TerrianType.AIR
	return voxels[_position_to_index(pos)] as TerrianData.TerrianType

func _position_to_index(pos: Vector3i) -> int:
	var index = pos.x + pos.z * chunk_size + pos.y * chunk_size * chunk_size
	return index
