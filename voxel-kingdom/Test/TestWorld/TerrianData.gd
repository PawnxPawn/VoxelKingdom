# TerrianData.gd
class_name TerrianData
extends Resource

enum TerrianType { DIRT, GRASS, STONE, WOOD, WOOD_PLANK, LEAVES, BEDROCK, AIR }

static var atlas_tiles: Dictionary[TerrianType, BlockFaceAtlas] = {}

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
	
	var wood: BlockFaceAtlas  = BlockFaceAtlas.new()
	wood.top = Vector2i(0, 3)
	wood.side = Vector2i(1,3)
	wood.bottom = Vector2i(0, 3)
	atlas_tiles[TerrianType.WOOD] = wood
	
	var wood_plank: BlockFaceAtlas  = BlockFaceAtlas.new()
	wood_plank.top = Vector2i(2, 3)
	wood_plank.side = Vector2i(2,3)
	wood_plank.bottom = Vector2i(2, 3)
	atlas_tiles[TerrianType.WOOD_PLANK] = wood_plank
	
	var leaves: BlockFaceAtlas  = BlockFaceAtlas.new()
	leaves.top = Vector2i(3, 3)
	leaves.side = Vector2i(3,3)
	leaves.bottom = Vector2i(3, 3)
	atlas_tiles[TerrianType.LEAVES] = leaves
	
	var bedrock := BlockFaceAtlas.new()
	bedrock.top = Vector2i(0, 2)
	bedrock.side = Vector2i(0, 2)
	bedrock.bottom = Vector2i(0, 2)
	atlas_tiles[TerrianType.BEDROCK] = bedrock

static func get_tile(block_type: TerrianType, location: int) -> Vector2i:
	var atlas: BlockFaceAtlas = atlas_tiles.get(block_type)
	if atlas == null:
		return Vector2i.ZERO
	match location:
		0: return atlas.top     # matches your pickup script's Location.TOP
		1: return atlas.bottom  # Location.BOTTOM
		2: return atlas.side    # Location.SIDES
	return Vector2i.ZERO


static func is_transparent(type: TerrianType) -> bool:
	return type == TerrianType.LEAVES
