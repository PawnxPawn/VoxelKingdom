#-###########################################
# Player
#-###########################################

class_name Player
extends Entity

enum HighlightMode { REMOVE, PLACE }

signal add_block(position: Vector3i, normal: Vector3i, terrian: TerrianData.TerrianType)
signal remove_block(position)

@export var chunk_manager: ChunkManager
@export var water_detector: WaterDetector
@export var player_height: float = 1.8
@export var player_radius: float = 0.4

@onready var default_cube_mesh: Cube = %DisplayItem
@onready var _handler: ComponentHandler = %ComponentHandler
@onready var _sm: StateMachine = %StateMachine
@onready var block_highlight: MeshInstance3D = $BlockHighlight
@onready var ray_cast: RayCast3D = $RayCast3D
@onready var water_overlay: WaterOverlay = %WaterOverlay
@onready var hand: AnimatedSprite2D = $Hand

var is_fly_active: bool = false

var camera: CameraComponent = null
var input: InputSource = null
var gravity: GravityComponent = null
var look: LookComponent = null

var highlight_mode: HighlightMode = HighlightMode.PLACE
var current_slot: int = 0
var terrian_type: TerrianData.TerrianType = TerrianData.TerrianType.DIRT

var _last_valid_position: Vector3

# Water state (from WaterDetector)
var _feet_submerged: bool = false
var _head_submerged: bool = false


# Animation Swapping
var _is_swapping: bool = false
var _is_removing: bool = false
var _swap_pending_value: int = 0
var _block_changed_this_swap: bool = false
var _block_removed_this_swing: bool = false
var _pending_remove_block: Vector3i = Vector3i.ZERO
var _has_pending_remove: bool = false

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

	# Water detection
	if water_detector:
		water_detector.feet_submerged_changed.connect(_on_feet_submerged)
		water_detector.head_submerged_changed.connect(_on_head_submerged)
	
	# Animation connections
	hand.animation_finished.connect(_change_animation)
	hand.frame_changed.connect(_on_hand_frame_changed)


#----------------
# Connect Components
#----------------
func _connect_components() -> void:
	# Input Component
	input = _handler.get_component(InputSource)
	if input:
		_handler.set_active(InputSource, true)
		input.add_block_pressed.connect(_on_add_block)
		input.remove_block_pressed.connect(_on_remove_block)
		input.item_switched_up.connect(play_swap_item.bind(1))
		input.item_switched_down.connect(play_swap_item.bind(-1))
	
	# Look Component
	look = _handler.get_component(LookComponent)
	if look and input:
		input.look_direction_changed.connect(look._on_look)
	
	# Gravity Component
	gravity = _handler.get_component(GravityComponent)
	if gravity:
		_handler.set_active(GravityComponent, true)
		gravity.chunk_manager = chunk_manager
	
	#Camera Component
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
	
	var head_location: Vector3 = Vector3(0.0, player_height, 0.0)
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
		if not _is_swapping and not _is_removing:
			play_display_idle()
		return HighlightMode.REMOVE
	if not _is_swapping and not _is_removing:
		play_remove_idle()
	return HighlightMode.PLACE


#----------------
# Change Block Type
#----------------
func _change_block(value: int) -> void:
	current_slot = wrapi(current_slot + value, 0, TerrianData.UseableBlock.size())
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


#-###############
# Calls
#-###############

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
	if _is_removing: return
	if _is_swapping: return
		
	var ray_hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if ray_hit == null:
		return
		
	var hit_block: Vector3i = Vector3i(
		round(ray_hit.hit_position - ray_hit.hit_normal * 0.5)
	)
	
	_is_removing = true
	_block_removed_this_swing = false
	_pending_remove_block = hit_block
	_has_pending_remove = true
	hand.play("RemoveBlock")


#----------------
# Body Submerged
#----------------
func _on_feet_submerged(is_submerged: bool) -> void:
	_feet_submerged = is_submerged
	
	if gravity:
		gravity.set_at_surface(is_at_water_surface())
	
	var current: StringName = _sm.get_current_state()
	
	if current == &"FlyState": return
	
	if is_submerged:
		if current != &"SwimState":
			_sm.change_state(&"SwimState")
	else:
		if current == &"SwimState":
			_sm.change_state(&"MoveState")


func _on_head_submerged(is_submerged: bool) -> void:
	_head_submerged = is_submerged
	
	if gravity:
		gravity.set_at_surface(is_at_water_surface())
	
	if water_overlay:
		water_overlay.set_submerged(is_submerged)


#----------------
# Water helpers
#----------------
func is_underwater() -> bool:
	return _feet_submerged and _head_submerged


func is_at_water_surface() -> bool:
	# Feet in water, head out of water ⇒ surface
	return _feet_submerged and not _head_submerged


#----------------
# Animations
#----------------

func play_swap_item(value: int) -> void:
	if _is_removing: return
	if _is_swapping: return
	_is_swapping = true
	_swap_pending_value = value
	_block_changed_this_swap = false
	hand.play("ItemSwap")


func _on_hand_frame_changed() -> void:
	match hand.animation:
		&"ItemSwap":
			if hand.frame == 2 and not _block_changed_this_swap:
				default_cube_mesh.hide()
				_change_block(_swap_pending_value)
				_block_changed_this_swap = true
			elif hand.frame == 9:
				default_cube_mesh.show()
				
		&"RemoveBlock":
			if hand.frame == 8 and not _block_removed_this_swing and _has_pending_remove:
				remove_block.emit(_pending_remove_block)
				_block_removed_this_swing = true
				_has_pending_remove = false


func _change_animation() -> void:
	match hand.animation:
		&"ItemSwap":
			_is_swapping = false
			if input.is_place_mode_active:
				play_display_idle()
			else:
				play_remove_idle()
		&"RemoveBlock":
			_is_removing = false
			play_remove_idle()


func play_display_idle() -> void:
	default_cube_mesh.show()
	hand.play(&"DisplayBlockIdle")


func play_remove_idle() -> void:
	default_cube_mesh.hide()
	hand.play(&"RemoveBlockIdle")
