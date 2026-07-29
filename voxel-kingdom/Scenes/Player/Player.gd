



class_name Player
extends Entity

signal add_block(position: Vector3i, normal: Vector3i, terrian: TerrianData.TerrianType)
signal remove_block(position)

@export var chunk_manager: ChunkManager
@export var water_detector: WaterDetector
@export var player_height: float = 1.8
@export var player_radius: float = 0.4


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


var _feet_submerged: bool = false
var _head_submerged: bool = false

var _is_wheel: bool = false


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

var move: MoveComponent = null
var _is_buried: bool = false

var _footstep_distance_accum: float = 0.0
const FOOTSTEP_STRIDE: float = 1.2 
var _ambient_timer: float = 0.0

const WATER_SCAN_RADIUS: int = 4
const LAVA_SCAN_RADIUS: int = 4
const CEILING_CHECK_HEIGHT: int = 24
const CAVE_SCAN_RADIUS_H: int = 3
const CAVE_SCAN_RADIUS_V: int = 2
var _cached_in_cave: bool = false

var _proximity_scan_timer: float = 0.0
const PROXIMITY_SCAN_INTERVAL: float = 0.25

func _ready() -> void :

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


	if water_detector:
		water_detector.feet_submerged_changed.connect(_on_feet_submerged)
		water_detector.head_submerged_changed.connect(_on_head_submerged)


	hand.animation_finished.connect(_change_animation)
	hand.frame_changed.connect(_on_hand_frame_changed)

	Services.ui.ui_hidden.connect(_unpause)

	play_display_idle()


func _connect_components() -> void :

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


	look = _handler.get_component(LookComponent)
	if look and input and _input_allowed:
		input.look_direction_changed.connect(look._on_look)


	gravity = _handler.get_component(GravityComponent)
	if gravity and _gravity_allowed:
		_handler.set_active(GravityComponent, true)
		gravity.chunk_manager = chunk_manager


	move = _handler.get_component(MoveComponent)


	_setup_camera()


func _pause() -> void :
	if not _input_allowed: return
	if _pause_cooldown_frames > 0:
		return
	_input_allowed = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Services.ui.show_ui(UI.Uis.PAUSE)
	Services.game_state.change_game_state(GameState.GameStates.PAUSED)
	get_tree().paused = true


func _unpause(ui: UI.Uis) -> void :
	if ui != UI.Uis.PAUSE: return
	_input_allowed = true
	_handler.set_active(InputSource, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Services.game_state.change_game_state(GameState.GameStates.PLAYING)
	_pause_cooldown_frames = 3


func _setup_sm() -> void :
	_sm.init(_handler)


func _setup_camera() -> void :
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


func _process(_delta: float) -> void :
	var hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if hit == null:
		block_highlight.hide_highlight()
	else:
		var hit_pos: Vector3 = hit.hit_position
		var normal: Vector3 = hit.hit_normal
		var hit_block: Vector3i = Vector3i(round(hit_pos - normal * 0.5))
		block_highlight.show_at_block(hit_block)

	_update_ambient_sfx(_delta)

func _update_ambient_sfx(delta: float) -> void :
	_ambient_timer -= delta

	_proximity_scan_timer -= delta
	if _proximity_scan_timer <= 0.0:
		_proximity_scan_timer = PROXIMITY_SCAN_INTERVAL
		_update_lava_proximity()
		_update_water_proximity()
		_cached_in_cave = _is_in_cave()

	if ScreenEffects:
		ScreenEffects.set_cave_intensity(_cached_in_cave)

	if _ambient_timer > 0.0 or not Services.audio:
		return

	if _cached_in_cave:
		Services.audio.play_sfx(Audio.SFX_Titles.CAVE_WATER_DRIP, randf_range(-16.0, -10.0), randf_range(0.85, 1.15))
		_ambient_timer = randf_range(15.0, 30.0)
	else:
		_ambient_timer = 1.0


func _update_water_proximity() -> void :
	if chunk_manager == null or not Services.audio:
		return

	if _feet_submerged or _head_submerged:
		Services.audio.set_water_proximity(true, 0.0, _head_submerged)
		return

	var player_pos: Vector3i = Vector3i(roundi(global_position.x), roundi(global_position.y), roundi(global_position.z))
	var closest_dist_sq: int = -1

	for dx in range(-WATER_SCAN_RADIUS, WATER_SCAN_RADIUS + 1, 2):
		for dy in range(-WATER_SCAN_RADIUS, WATER_SCAN_RADIUS + 1, 2):
			for dz in range(-WATER_SCAN_RADIUS, WATER_SCAN_RADIUS + 1, 2):
				var dist_sq: int = dx * dx + dy * dy + dz * dz
				if dist_sq > WATER_SCAN_RADIUS * WATER_SCAN_RADIUS:
					continue
				var check_pos: Vector3i = player_pos + Vector3i(dx, dy, dz)
				if TerrianData.is_water(chunk_manager.get_voxel_type_at(check_pos)):
					if closest_dist_sq == -1 or dist_sq < closest_dist_sq:
						closest_dist_sq = dist_sq

	if closest_dist_sq == -1:
		Services.audio.set_water_proximity(false)
		return

	var closest_dist: float = sqrt(float(closest_dist_sq))
	var falloff: float = 1.0 - clampf(closest_dist / float(WATER_SCAN_RADIUS), 0.0, 1.0)
	var volume_db: float = lerp(-24.0, 0.0, falloff)
	Services.audio.set_water_proximity(true, volume_db, false)


func _update_lava_proximity() -> void :
	if chunk_manager == null or not Services.audio:
		return

	var player_pos: Vector3i = Vector3i(roundi(global_position.x), roundi(global_position.y), roundi(global_position.z))
	var closest_dist_sq: int = -1

	for dx in range(-LAVA_SCAN_RADIUS, LAVA_SCAN_RADIUS + 1, 2):
		for dy in range(-LAVA_SCAN_RADIUS, LAVA_SCAN_RADIUS + 1, 2):
			for dz in range(-LAVA_SCAN_RADIUS, LAVA_SCAN_RADIUS + 1, 2):
				var dist_sq: int = dx * dx + dy * dy + dz * dz
				if dist_sq > LAVA_SCAN_RADIUS * LAVA_SCAN_RADIUS:
					continue
				var check_pos: Vector3i = player_pos + Vector3i(dx, dy, dz)
				if TerrianData.is_lava(chunk_manager.get_voxel_type_at(check_pos)):
					if closest_dist_sq == -1 or dist_sq < closest_dist_sq:
						closest_dist_sq = dist_sq

	if closest_dist_sq == -1:
		Services.audio.set_lava_proximity(false)
		if ScreenEffects:
			ScreenEffects.set_lava_proximity(0.0)
			ScreenEffects.set_in_lava(false)
		return

	var closest_dist: float = sqrt(float(closest_dist_sq))
	var falloff: float = 1.0 - clampf(closest_dist / float(LAVA_SCAN_RADIUS), 0.0, 1.0)
	var volume_db: float = lerp(-24.0, 0.0, falloff)
	Services.audio.set_lava_proximity(true, volume_db)

	if ScreenEffects:
		ScreenEffects.set_lava_proximity(falloff)
		ScreenEffects.set_in_lava(_feet_in_lava or _head_in_lava)

func _is_in_cave() -> bool:
	if chunk_manager == null:
		return false

	if global_position.y >= chunk_manager.water_level:
		return false

	if not _has_ceiling_above():
		print("no ceiling")
		return false

	var air_count: int = 0
	var total: int = 0
	var player_pos: Vector3i = Vector3i(roundi(global_position.x), roundi(global_position.y), roundi(global_position.z))

	for dx in range(-CAVE_SCAN_RADIUS_H, CAVE_SCAN_RADIUS_H + 1):
		for dy in range(-1, CAVE_SCAN_RADIUS_V + 1):
			for dz in range(-CAVE_SCAN_RADIUS_H, CAVE_SCAN_RADIUS_H + 1):
				total += 1
				var check_pos: Vector3i = player_pos + Vector3i(dx, dy, dz)
				if chunk_manager.get_voxel_type_at(check_pos) == TerrianData.TerrianType.AIR:
					air_count += 1

	var ratio: float = float(air_count) / float(total)
	return ratio > 0.2


func _has_ceiling_above() -> bool:
	var player_pos: Vector3i = Vector3i(roundi(global_position.x), roundi(global_position.y), roundi(global_position.z))
	for dy in range(2, CEILING_CHECK_HEIGHT + 1):
		var check_pos: Vector3i = player_pos + Vector3i(0, dy, 0)
		var voxel_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(check_pos)
		if voxel_type == TerrianData.TerrianType.AIR:
			continue
		if voxel_type == TerrianData.TerrianType.LEAVES:
			continue
		return true
	return false

func _physics_process(_delta: float) -> void :
	if _pause_cooldown_frames > 0:
		_pause_cooldown_frames -= 1
		return

	if _player_auto_rotate:
		look._on_look(Vector2(_rotation_speed * _delta, 0))
	_update_buried_state()
	_update_footsteps(_delta)
	_loaded_chunk_bounds()
	camera.set_rotation(look.pitch, look.yaw, 0)

func _update_footsteps(delta: float) -> void :
	if _feet_submerged or _feet_in_lava:
		_footstep_distance_accum = 0.0
		return

	var current_state: StringName = _sm.get_current_state()
	if current_state != &"MoveState":
		_footstep_distance_accum = 0.0
		return

	var horizontal_velocity: Vector3 = velocity * Vector3(1, 0, 1)
	var speed: float = horizontal_velocity.length()
	if speed < 0.1:
		return

	_footstep_distance_accum += speed * delta
	if _footstep_distance_accum >= FOOTSTEP_STRIDE:
		_footstep_distance_accum = 0.0
		_play_footstep()

func _play_footstep() -> void :
	if chunk_manager == null or not Services.audio:
		return
	var ground_pos: Vector3i = Vector3i(
		roundi(global_position.x), 
		roundi(global_position.y - 0.1), 
		roundi(global_position.z)
	)
	var ground_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(ground_pos)
	Services.audio.play_sfx(Services.audio.get_walk_sfx(ground_type), 0.0, randf_range(0.95, 1.05))



func _loaded_chunk_bounds() -> void :
	if chunk_manager == null:
		return

	if chunk_manager.is_chunk_loaded_at(global_position):
		_last_valid_position = global_position
	else:
		global_position = _last_valid_position



func _change_block(value: int, is_wheel: bool = false) -> void :
	if is_wheel:
		current_slot = wrapi(current_slot + value, 0, TerrianData.UseableBlock.size())
	else:
		current_slot = wrapi(value, 0, TerrianData.UseableBlock.size())

	_change_inventory_highlight(current_slot)

	terrian_type = TerrianData.TerrianType.values()[current_slot]
	default_cube_mesh.change_block_type(terrian_type)


func _change_inventory_highlight(slot: int) -> void :
	const start_pos: Vector2 = Vector2(6.0, 6.0)
	highlight_inventory_slot.position.x = start_pos.x + (highlight_inventory_slot.size.x * slot) + 1 + current_slot if slot > 0 else start_pos.x



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


func _on_add_block() -> void :
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


func _on_remove_block() -> void :
	if not _input_allowed: return


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


func _cancel_swap_for_removal() -> void :
	if not _block_changed_this_swap:
		default_cube_mesh.hide()
		_change_block(_swap_pending_value, _is_wheel)
		_block_changed_this_swap = true

	_is_swapping = false


func _on_feet_submerged(is_submerged: bool, kind: WaterOverlay.FluidKind) -> void :
	_feet_submerged = is_submerged
	_feet_in_lava = (kind == WaterOverlay.FluidKind.LAVA)

	if kind != WaterOverlay.FluidKind.LAVA and Services.audio:
		if is_submerged:
			Services.audio.play_water_enter(false)
		else:
			Services.audio.play_water_exit(false)

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


func _on_head_submerged(is_submerged: bool, kind: WaterOverlay.FluidKind) -> void :
	_head_submerged = is_submerged
	_head_in_lava = (kind == WaterOverlay.FluidKind.LAVA)

	water_overlay.set_submerged(is_submerged, kind)

	if kind != WaterOverlay.FluidKind.LAVA and Services.audio:
		if is_submerged:
			Services.audio.play_water_enter(true)
		else:
			Services.audio.play_water_exit(true)
			if ScreenEffects:
				ScreenEffects.trigger_droplets()

	if gravity:
		gravity.set_at_surface(is_at_liquid_surface())


func is_under_liquid() -> bool:
	return (_feet_submerged or _feet_in_lava) and (_head_submerged or _head_in_lava)


func is_at_liquid_surface() -> bool:
	return (_feet_submerged or _feet_in_lava) and not (_head_submerged or _head_in_lava)

func is_in_lava() -> bool:
	return _feet_in_lava or _head_in_lava






func play_swap_item(value: int, is_wheel: bool = false) -> void :
	if not _input_allowed: return
	if _is_removing: return
	if _is_swapping: return
	_is_swapping = true
	_is_wheel = is_wheel
	_swap_pending_value = value
	_block_changed_this_swap = false
	hand.play("ItemSwap")


func _on_hand_frame_changed() -> void :
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


func _change_animation() -> void :
	match hand.animation:
		&"ItemSwap":
			_is_swapping = false
			play_display_idle()
		&"RemoveBlock":
			_is_removing = false
			play_display_idle()


func play_display_idle() -> void :
	default_cube_mesh.show()
	hand.play(&"DisplayBlockIdle")


func _update_buried_state() -> void :
	if chunk_manager == null:
		return

	var feet_pos: Vector3
	var head_pos: Vector3

	if water_detector != null and water_detector.feet_point != null and water_detector.head_point != null:
		feet_pos = water_detector.feet_point.global_position
		head_pos = water_detector.head_point.global_position
	else:
		feet_pos = global_position
		head_pos = global_position + Vector3(0.0, player_height, 0.0)

	var feet_voxel: Vector3i = Vector3i(
		roundi(feet_pos.x), 
		roundi(feet_pos.y + 0.2), 
		roundi(feet_pos.z)
	)
	var head_voxel: Vector3i = Vector3i(
		roundi(head_pos.x), 
		roundi(head_pos.y - 0.2), 
		roundi(head_pos.z)
	)

	var feet_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(feet_voxel)
	var head_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(head_voxel)

	var buried: bool = TerrianData.is_solid_terrain(feet_type) or TerrianData.is_solid_terrain(head_type)

	_is_buried = buried

	if gravity:
		gravity.is_buried = buried
	if move:
		move.is_buried = buried
