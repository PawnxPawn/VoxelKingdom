#-###########################################
# TerrianData
#-###########################################

class_name TerrianData
extends Resource

# NOTE:
# WATER_FLOW_1..7 are appended at the END of the enum on purpose.
# Changing their order would shift integer values stored in ChunkData.voxels.

enum TerrianType {
	DIRT, GRASS, STONE, WOOD, WOOD_PLANK, LEAVES, WATER, BEDROCK, AIR,
	WATER_FLOW_1, WATER_FLOW_2, WATER_FLOW_3, WATER_FLOW_4,
	WATER_FLOW_5, WATER_FLOW_6, WATER_FLOW_7
}

const MAX_WATER_FLOW_DISTANCE: int = 7

static var atlas_tiles: Dictionary[TerrianType, BlockFaceAtlas] = {}


#----------------
# Static Init
#----------------
static func _static_init() -> void:
	var grass: BlockFaceAtlas = BlockFaceAtlas.new()
	grass.top = Vector2i(2, 0)
	grass.side = Vector2i(1, 0)
	grass.bottom = Vector2i(0, 0)
	atlas_tiles[TerrianType.GRASS] = grass
	
	var dirt: BlockFaceAtlas = BlockFaceAtlas.new()
	dirt.top = Vector2i(0, 0)
	dirt.side = Vector2i(0, 0)
	dirt.bottom = Vector2i(0, 0)
	atlas_tiles[TerrianType.DIRT] = dirt
	
	var stone: BlockFaceAtlas = BlockFaceAtlas.new()
	stone.top = Vector2i(0, 1)
	stone.side = Vector2i(0, 1)
	stone.bottom = Vector2i(0, 1)
	atlas_tiles[TerrianType.STONE] = stone
	
	var wood: BlockFaceAtlas = BlockFaceAtlas.new()
	wood.top = Vector2i(0, 3)
	wood.side = Vector2i(1, 3)
	wood.bottom = Vector2i(0, 3)
	atlas_tiles[TerrianType.WOOD] = wood
	
	var wood_plank: BlockFaceAtlas = BlockFaceAtlas.new()
	wood_plank.top = Vector2i(2, 3)
	wood_plank.side = Vector2i(2, 3)
	wood_plank.bottom = Vector2i(2, 3)
	atlas_tiles[TerrianType.WOOD_PLANK] = wood_plank
	
	var leaves: BlockFaceAtlas = BlockFaceAtlas.new()
	leaves.top = Vector2i(3, 3)
	leaves.side = Vector2i(3, 3)
	leaves.bottom = Vector2i(3, 3)
	atlas_tiles[TerrianType.LEAVES] = leaves
	
	var water: BlockFaceAtlas = BlockFaceAtlas.new()
	water.top = Vector2i(1, 2)
	water.side = Vector2i(1, 2)
	water.bottom = Vector2i(1, 2)
	atlas_tiles[TerrianType.WATER] = water
	
	for level: int in range(1, MAX_WATER_FLOW_DISTANCE + 1):
		atlas_tiles[water_type_for_level(level)] = water
	
	var bedrock: BlockFaceAtlas = BlockFaceAtlas.new()
	bedrock.top = Vector2i(0, 2)
	bedrock.side = Vector2i(0, 2)
	bedrock.bottom = Vector2i(0, 2)
	atlas_tiles[TerrianType.BEDROCK] = bedrock


#----------------
# Tile Lookup
#----------------
static func get_tile(block_type: TerrianType, location: int) -> Vector2i:
	var atlas: BlockFaceAtlas = atlas_tiles.get(block_type)
	if atlas == null:
		return Vector2i.ZERO
	
	match location:
		0: return atlas.top
		1: return atlas.bottom
		2: return atlas.side
	
	return Vector2i.ZERO


#----------------
# Transparency
#----------------
static func is_transparent(type: TerrianType) -> bool:
	return type == TerrianType.LEAVES or is_water(type)


#-###########################################
# Water Helpers
#-###########################################

static func is_water(type: TerrianType) -> bool:
	return type == TerrianType.WATER or (type >= TerrianType.WATER_FLOW_1 and type <= TerrianType.WATER_FLOW_7)


static func get_water_level(type: TerrianType) -> int:
	if type == TerrianType.WATER:
		return 0
	if type >= TerrianType.WATER_FLOW_1 and type <= TerrianType.WATER_FLOW_7:
		return int(type) - int(TerrianType.WATER_FLOW_1) + 1
	return -1


static func water_type_for_level(level: int) -> TerrianType:
	if level <= 0:
		return TerrianType.WATER
	return (TerrianType.WATER_FLOW_1 + (level - 1)) as TerrianType
