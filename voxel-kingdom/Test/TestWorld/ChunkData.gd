#-###########################################
# ChunkData
#-###########################################

class_name ChunkData
extends Resource

var voxels: PackedInt32Array
var chunk_size: int = 32
var voxel_amount: int = 0


#----------------
# Init
#----------------
func _init() -> void:
	set_size(chunk_size)


#----------------
# Set Size
#----------------
func set_size(size: int) -> void:
	chunk_size = size
	
	voxels = PackedInt32Array()
	voxels.resize(size * size * size)
	voxels.fill(TerrianData.TerrianType.AIR)
	
	voxel_amount = 0


#----------------
# Add Voxel
#----------------
func add_voxel(pos: Vector3i, voxel_type: TerrianData.TerrianType) -> void:
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or pos.x >= chunk_size or pos.y >= chunk_size or pos.z >= chunk_size:
		return
	
	var index: int = _position_to_index(pos)
	var previous_type: int = voxels[index]
	
	voxels[index] = voxel_type
	
	if previous_type == TerrianData.TerrianType.AIR and voxel_type != TerrianData.TerrianType.AIR:
		voxel_amount += 1
	elif previous_type != TerrianData.TerrianType.AIR and voxel_type == TerrianData.TerrianType.AIR:
		voxel_amount -= 1


#----------------
# Remove Voxel
#----------------
func remove_voxel(pos: Vector3i) -> void:
	var voxel: int = get_voxel(pos)
	if voxel == TerrianData.TerrianType.AIR:
		return
	
	voxels[_position_to_index(pos)] = TerrianData.TerrianType.AIR
	voxel_amount -= 1


#----------------
# Voxel Count
#----------------
func get_number_of_voxels() -> int:
	return voxel_amount


func is_empty() -> bool:
	return voxel_amount <= 0


#----------------
# Voxel Access
#----------------
func get_voxels_copy() -> PackedInt32Array:
	return voxels


func get_voxel(pos: Vector3i) -> TerrianData.TerrianType:
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or pos.x >= chunk_size or pos.y >= chunk_size or pos.z >= chunk_size:
		return TerrianData.TerrianType.AIR
	
	return voxels[_position_to_index(pos)] as TerrianData.TerrianType


#----------------
# Position -> Index
#----------------
func _position_to_index(pos: Vector3i) -> int:
	return pos.x + pos.z * chunk_size + pos.y * chunk_size * chunk_size
