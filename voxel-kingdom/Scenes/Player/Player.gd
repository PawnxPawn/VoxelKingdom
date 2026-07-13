#-###########################################
# Player
#-###########################################

class_name Player
extends Entity

enum HighlightMode { REMOVE, PLACE }

signal add_block(position: Vector3i, normal: Vector3i, terrian: TerrianData.TerrianType)
signal remove_block(position)

@export var chunk_manager: ChunkManager
@export var player_height: float = 1.8
@export var player_radius: float = 0.4

@onready var default_cube_mesh: Cube = $SubViewportinfo/DefaultCubeMesh
@onready var _handler: ComponentHandler = %ComponentHandler
@onready var _sm: StateMachine = %StateMachine
@onready var block_highlight: MeshInstance3D = $BlockHighlight
@onready var ray_cast: RayCast3D = $RayCast3D

var is_fly_active: bool = false

var camera: CameraComponent = null
var input: InputSource = null
var gravity: GravityComponent = null
var look: LookComponent = null

var highlight_mode: HighlightMode = HighlightMode.PLACE
var current_slot: int = 0
var terrian_type: TerrianData.TerrianType = TerrianData.TerrianType.DIRT

var _last_valid_position: Vector3


#----------------
# Ready
#----------------
func _ready() -> void:
	_connect_components()
	_setup_sm()
	default_cube_mesh.change_block_type(terrian_type)
	
	var world_spawn: Vector3 = Vector3(
		chunk_manager.world_dimensions.x / 2.0,
		global_position.y,
		chunk_manager.world_dimensions.z / 2.0
	)
	
	global_position = world_spawn
	_last_valid_position = global_position


#----------------
# Connect Components
#----------------
func _connect_components() -> void:
	input = _handler.get_component(InputSource)
	if input:
		_handler.set_active(InputSource, true)
		input.add_block_pressed.connect(_on_add_block)
		input.remove_block_pressed.connect(_on_remove_block)
		input.item_switched_up.connect(_change_block.bind(1))
		input.item_switched_down.connect(_change_block.bind(-1))
	
	look = _handler.get_component(LookComponent)
	if look and input:
		input.look_direction_changed.connect(look._on_look)
	
	gravity = _handler.get_component(GravityComponent)
	if gravity:
		_handler.set_active(GravityComponent, true)
	
	_setup_camera()


#----------------
# Setup State Machine
#----------------
func _setup_sm() -> void:
	_sm.init(_handler)


#----------------
# Setup Camera
#----------------
func _setup_camera() -> void:
	camera = _handler.get_component(CameraComponent)
	if not camera:
		return
	
	ray_cast.reparent(camera.camera)
	ray_cast.position = Vector3.ZERO
	
	var head_location := Vector3(0.0, 1.8, 0.0)
	camera.set_position(head_location)
	
	camera.set_camera_cull_layers({
		19: false,
		20: false,
	})


#----------------
# Process
#----------------
func _process(_delta: float) -> void:
	var hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if hit == null:
		block_highlight.hide_highlight()
		return
	
	var hit_pos: Vector3 = hit.hit_position
	var normal: Vector3 = hit.hit_normal
	
	var hit_block: Vector3i = Vector3i(round(hit_pos - normal * 0.5))
	var normal_dir: Vector3i = Vector3i(round(normal.x), round(normal.y), round(normal.z))
	
	var target_block: Vector3i = hit_block if get_mode() else hit_block + normal_dir
	
	block_highlight.show_at_block(target_block)


#----------------
# Physics Process
#----------------
func _physics_process(_delta: float) -> void:
	_loaded_chunk_bounds()
	camera.set_rotation(look.pitch, look.yaw, 0)


#----------------
# Chunk Bounds
#----------------
func _loaded_chunk_bounds() -> void:
	if chunk_manager == null:
		return
	
	if chunk_manager.is_chunk_loaded_at(global_position):
		_last_valid_position = global_position
	else:
		global_position = _last_valid_position


#----------------
# Highlight Mode
#----------------
func get_mode() -> HighlightMode:
	if input.is_place_mode_active:
		return HighlightMode.REMOVE
	return HighlightMode.PLACE


#----------------
# Change Block Type
#----------------
func _change_block(value: int) -> void:
	current_slot = wrapi(current_slot + value, 0, TerrianData.TerrianType.size() - 2)
	terrian_type = TerrianData.TerrianType.values()[current_slot]
	default_cube_mesh.change_block_type(terrian_type)


#----------------
# Player Overlap Check
#----------------
func _would_overlap_player(target_block: Vector3i) -> bool:
	var blocks: Array[Vector3i] = []
	var rounded_pos: Vector3i = Vector3i(
		round(global_position.x),
		ceil(global_position.y),
		round(global_position.z)
	)
	
	blocks.append(rounded_pos)
	blocks.append(Vector3i(rounded_pos.x, rounded_pos.y + 1, rounded_pos.z))
	
	return blocks.has(target_block)


#----------------
# Add Block
#----------------
func _on_add_block() -> void:
	var ray_hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if ray_hit == null:
		return
	
	var normal_dir: Vector3i = Vector3i(
		round(ray_hit.hit_normal.x),
		round(ray_hit.hit_normal.y),
		round(ray_hit.hit_normal.z)
	)
	
	var target_block: Vector3i = Vector3i(
		round(ray_hit.hit_position - ray_hit.hit_normal * 0.5)
	) + normal_dir
	
	if _would_overlap_player(target_block):
		return
	
	add_block.emit(target_block, normal_dir, terrian_type)


#----------------
# Remove Block
#----------------
func _on_remove_block() -> void:
	var ray_hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if ray_hit == null:
		return
	
	var hit_block: Vector3i = Vector3i(
		round(ray_hit.hit_position - ray_hit.hit_normal * 0.5)
	)
	
	remove_block.emit(hit_block)
