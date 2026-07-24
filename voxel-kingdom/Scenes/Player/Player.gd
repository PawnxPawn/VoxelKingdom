#-###########################################
# Player
#-###########################################

class_name Player
extends Entity

signal add_block(position: Vector3i, normal: Vector3i, terrian: TerrianData.TerrianType)
signal remove_block(position)

@export var chunk_manager: ChunkManager
@export var water_detector: WaterDetector
@export var player_height: float = 1.8
@export var player_radius: float = 0.4

#Title Menu Settings
@export var _in_main_menu: bool = false
@export var _gravity_allowed: bool = true
@export var _input_allowed: bool = true
@export var _player_auto_rotate: bool = false
@export var _rotation_speed: float = 0.01

@onready var default_cube_mesh: Cube = %DisplayItem
@onready var _handler: ComponentHandler = %ComponentHandler
@onready var _sm: StateMachine = %StateMachine
@onready var block_highlight: MeshInstance3D = $BlockHighlight
@onready var ray_cast: RayCast3D = $RayCast3D
@onready var water_overlay: WaterOverlay = %WaterOverlay
@onready var hand: AnimatedSprite2D = $Hand
@onready var highlight_inventory_slot: TextureRect = %HighlightInventorySlot

var is_fly_active: bool = false

var camera: CameraComponent = null
var input: InputSource = null
var gravity: GravityComponent = null
var look: LookComponent = null

var current_slot: int = 0
var terrian_type: TerrianData.TerrianType = TerrianData.TerrianType.DIRT

var _last_valid_position: Vector3

# Water state (from WaterDetector)
var _feet_submerged: bool = false
var _head_submerged: bool = false

var _is_wheel: bool = false

# Animation Swapping
var _is_swapping: bool = false
var _is_removing: bool = false
var _swap_pending_value: int = 0
var _block_changed_this_swap: bool = false
var _block_removed_this_swing: bool = false
var _pending_remove_block: Vector3i = Vector3i.ZERO
var _has_pending_remove: bool = false

var _pause_cooldown_frames: int = 0

var _feet_in_lava: bool = false
var _head_in_lava: bool = false


#----------------
# Ready
#----------------
func _ready() -> void:
		
	_connect_components()
	_setup_sm()
	if _in_main_menu:
		_sm.change_state(&"MenuState")
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
	
	Services.ui.ui_hidden.connect(_unpause)
	
	play_display_idle()


#----------------
# Connect Components
#----------------
func _connect_components() -> void:
	# Input Component
	input = _handler.get_component(InputSource)
	if input:
		_handler.set_active(InputSource, true)
		if _input_allowed:
			input.add_block_pressed.connect(_on_add_block)
			input.remove_block_pressed.connect(_on_remove_block)
			input.item_switched.connect(play_swap_item.bind(true))
			input.item_slot_pressed.connect(play_swap_item)
			input.paused_pressed.connect(_pause)
		else:
			input.allow_mouse = true
	
	# Look Component
	look = _handler.get_component(LookComponent)
	if look and input and _input_allowed:
		input.look_direction_changed.connect(look._on_look)
	
	# Gravity Component
	gravity = _handler.get_component(GravityComponent)
	if gravity and _gravity_allowed:
		_handler.set_active(GravityComponent, true)
		gravity.chunk_manager = chunk_manager
	
	#Camera Component
	_setup_camera()


func _pause() -> void:
	if not _input_allowed: return
	if _pause_cooldown_frames > 0:
		return
	_input_allowed = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Services.ui.show_ui(UI.Uis.PAUSE)
	Services.game_state.change_game_state(GameState.GameStates.PAUSED)
	get_tree().paused = true


func _unpause(ui:UI.Uis) -> void:
	if ui != UI.Uis.PAUSE: return
	_input_allowed = true
	_handler.set_active(InputSource, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Services.game_state.change_game_state(GameState.GameStates.PLAYING)
	_pause_cooldown_frames = 3


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
	
	block_highlight.show_at_block(hit_block)


#----------------
# Physics Process
#----------------
func _physics_process(_delta: float) -> void:
	if _pause_cooldown_frames > 0:
		_pause_cooldown_frames -= 1
		return
	
	if _player_auto_rotate:
		look._on_look(Vector2(_rotation_speed * _delta,0))
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
# Change Block Type
#----------------
func _change_block(value: int, is_wheel:bool = false) -> void:
	if is_wheel:
		current_slot = wrapi(current_slot + value, 0, TerrianData.UseableBlock.size())
	else:
		current_slot = wrapi(value, 0, TerrianData.UseableBlock.size()) 
	
	_change_inventory_highlight(current_slot)
	
	terrian_type = TerrianData.TerrianType.values()[current_slot]
	default_cube_mesh.change_block_type(terrian_type)


func _change_inventory_highlight(slot:int) -> void:
	const start_pos: Vector2 = Vector2(6.0, 6.0)
	highlight_inventory_slot.position.x = start_pos.x + (highlight_inventory_slot.size.x * slot) + 1 + current_slot if slot > 0 else start_pos.x


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
	if not _input_allowed: return
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
	if not _input_allowed: return
	#if _is_removing: return
		
	var ray_hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if ray_hit == null:
		return
		
	var hit_block: Vector3i = Vector3i(
		round(ray_hit.hit_position - ray_hit.hit_normal * 0.5)
	)
	
	if _is_swapping:
		_cancel_swap_for_removal()
	
	_is_removing = true
	_block_removed_this_swing = false
	_pending_remove_block = hit_block
	_has_pending_remove = true
	default_cube_mesh.hide()
	hand.play("RemoveBlock")


#----------------
# Cancel Swap
#----------------
func _cancel_swap_for_removal() -> void:
	if not _block_changed_this_swap:
		default_cube_mesh.hide()
		_change_block(_swap_pending_value, _is_wheel)
		_block_changed_this_swap = true
	
	_is_swapping = false


#----------------
# Body Submerged
#----------------
func _on_feet_submerged(is_submerged: bool, kind: WaterOverlay.FluidKind) -> void:
	_feet_submerged = is_submerged
	_feet_in_lava = (kind == WaterOverlay.FluidKind.LAVA)
	
	if gravity:
		gravity.set_at_surface(is_at_liquid_surface())
	
	var current: StringName = _sm.get_current_state()
	if current == &"FlyState":
		return
	
	if is_submerged:
		if current != &"SwimState":
			_sm.change_state(&"SwimState")
	else:
		if current == &"SwimState":
			_sm.change_state(&"MoveState")


func _on_head_submerged(is_submerged: bool, kind: WaterOverlay.FluidKind) -> void:
	_head_submerged = is_submerged
	_head_in_lava = (kind == WaterOverlay.FluidKind.LAVA)
	
	water_overlay.set_submerged(is_submerged, kind)
	
	if gravity:
		gravity.set_at_surface(is_at_liquid_surface())



#----------------
# Water helpers
#----------------
func is_under_liquid() -> bool:
	return (_feet_submerged or _feet_in_lava) and (_head_submerged or _head_in_lava)


func is_at_liquid_surface() -> bool:
	return (_feet_submerged or _feet_in_lava) and not (_head_submerged or _head_in_lava)

func is_in_lava() -> bool:
	return _feet_in_lava or _head_in_lava


#----------------
# Animations
#----------------

func play_swap_item(value: int, is_wheel:bool = false) -> void:
	if not _input_allowed: return
	if _is_removing: return
	if _is_swapping: return
	_is_swapping = true
	_is_wheel = is_wheel
	_swap_pending_value = value
	_block_changed_this_swap = false
	hand.play("ItemSwap")


func _on_hand_frame_changed() -> void:
	match hand.animation:
		&"ItemSwap":
			if hand.frame == 2 and not _block_changed_this_swap:
				default_cube_mesh.hide()
				_change_block(_swap_pending_value, _is_wheel)
				_block_changed_this_swap = true
			elif hand.frame == 9:
				default_cube_mesh.show()
				
		&"RemoveBlock":
			if not _block_removed_this_swing and _has_pending_remove:
				remove_block.emit(_pending_remove_block)
				_block_removed_this_swing = true
				_has_pending_remove = false


func _change_animation() -> void:
	match hand.animation:
		&"ItemSwap":
			_is_swapping = false
			play_display_idle()
		&"RemoveBlock":
			_is_removing = false
			play_display_idle()


func play_display_idle() -> void:
	default_cube_mesh.show()
	hand.play(&"DisplayBlockIdle")
