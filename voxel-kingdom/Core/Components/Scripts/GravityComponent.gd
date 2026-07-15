#-###########################################
# Gravity Component
#-###########################################

class_name GravityComponent extends Component

signal grounded
signal left_floor
signal climbed_out

const FLOOR_DOT_MIN: float = 0.99

var max_fall_speed: float = 40.0

var gravity_ascent: float = 15.0
var gravity_descent: float = 30.0

var is_on_floor: bool = false
var is_falling: bool = false
var _was_on_floor: bool = false

var is_flying: bool = false
var _ascend_input: bool = false
var _descend_input: bool = false

#-------------------
# Resource Exports
#-------------------
var normal_ascending_gravity: float = 10.0
var normal_descending_gravity: float = 15.0
var water_ascending_gravity: float = 2.0
var water_descending_gravity: float = 1.0

var jump_velocity: float = 4.0
var vertical_swim_acceleration: float = 6.0
var swim_vertical_speed: float = 8.0
var fly_up_down_speed: float = 4.0

var surface_bob_speed: float = 1.5
var climb_check_distance: float = 0.6
#-------- End Resources -----------


var chunk_manager: ChunkManager = null

var _is_at_surface: bool = false

#----------------
# Gravity Types
#----------------
enum GravityType {
	NORMAL,
	CUSTOM,
	WATER,
	FLYING,
	ZERO,
}

var gravity_type: GravityType = GravityType.NORMAL

var presets: Dictionary = {
	GravityType.NORMAL: {
		&"ascent": normal_ascending_gravity,
		&"descent": normal_descending_gravity,
	},

	GravityType.WATER: {
		&"ascent": water_ascending_gravity,
		&"descent": water_descending_gravity,
	},

	GravityType.FLYING: {
		&"ascent": 0.0,
		&"descent": 0.0,
	},

	GravityType.ZERO: {
		&"ascent": 0.0,
		&"descent": 0.0,
	},
}

#----------------
# (TEMP) Climb Properties
#----------------

var _is_climbing_out: bool = false
var _climb_timer: float = 0.0
var _climb_duration: float = 0.12
var _climb_start: Vector3
var _climb_end: Vector3


#----------------
# Lifecycle
#----------------
func _init(p_owner: Node) -> void:
	super(p_owner)
	
	if _owner is RigidBody2D:
		var body: RigidBody2D = _owner
		body.gravity_scale = 0.0
		body.can_sleep = false


func ready() -> void:
	presets[GravityType.NORMAL][&"ascent"] = normal_ascending_gravity
	presets[GravityType.NORMAL][&"descent"] = normal_descending_gravity
	presets[GravityType.WATER][&"ascent"] = water_ascending_gravity
	presets[GravityType.WATER][&"descent"] = water_descending_gravity
	
	gravity_ascent = normal_ascending_gravity
	gravity_descent = normal_descending_gravity


func physics_process(delta: float) -> void:
	if _is_climbing_out:
		_climb_timer += delta
		var normalized_time: float = clamp(_climb_timer / _climb_duration, 0.0, 1.0)
		
		_owner.global_position = _climb_start.lerp(_climb_end, normalized_time)
		_owner.velocity = Vector3.ZERO
		
		if normalized_time >= 1.0:
			_is_climbing_out = false
			climbed_out.emit()
		return
		
	# normal gravity logic continues...
	apply_characterbody_gravity()



func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	is_on_floor_check(state)
	rigid2d_apply_gravity(state)


#----------------
# Floor Check (RigidBody2D)
#----------------
func is_on_floor_check(state: PhysicsDirectBodyState2D) -> void:
	_was_on_floor = is_on_floor
	is_on_floor = false
	
	for i in state.get_contact_count():
		var normal_dot: float = state.get_contact_local_normal(i).dot(Vector2.UP)
		
		if normal_dot > FLOOR_DOT_MIN:
			is_on_floor = true
			break
	
	if is_on_floor and not _was_on_floor:
		state.linear_velocity.y = 0.0
		grounded.emit()
	elif not is_on_floor and _was_on_floor:
		left_floor.emit()


#----------------
# Gravity (CharacterBody2D / CharacterBody3D)
#----------------
func apply_characterbody_gravity() -> void:
	if gravity_type == GravityType.WATER:
		apply_water_gravity()
		return
	
	if gravity_type == GravityType.FLYING:
		apply_flying_gravity()
		return
	
	if gravity_type == GravityType.ZERO:
		return
	
	if _owner.is_on_floor() and not is_flying:
		if not _was_on_floor:
			is_falling = false
			grounded.emit()
		
		_was_on_floor = true
		return
	
	if _was_on_floor:
		left_floor.emit()
	
	_was_on_floor = false
	
	if _owner.velocity.y < 0.0:
		is_falling = true
	
	var gravity_force: float = gravity_ascent if _owner.velocity.y > 0.0 else gravity_descent
	
	_owner.velocity.y = max(
		_owner.velocity.y - gravity_force * _owner.get_physics_process_delta_time(),
		-max_fall_speed
	)


#----------------
# Water Gravity
#----------------
func apply_water_gravity() -> void:
	var delta: float = _owner.get_physics_process_delta_time()
	var vertical_direction: float = float(_ascend_input) - float(_descend_input)
	
	if _ascend_input and _is_at_surface and chunk_manager != null:
		if _try_climb_out():
			return
	
	var target_velocity: float
	
	if vertical_direction > 0.0:
		target_velocity = surface_bob_speed if _is_at_surface else swim_vertical_speed
	elif vertical_direction < 0.0:
		target_velocity = -swim_vertical_speed
	else:
		target_velocity = -water_descending_gravity * 0.3
	
	_owner.velocity.y = move_toward(_owner.velocity.y, target_velocity, vertical_swim_acceleration * delta)
	_owner.velocity.y = clamp(_owner.velocity.y, -5.0, swim_vertical_speed)


#----------------
# Climb Out (surface -> ledge)
#----------------
func _try_climb_out() -> bool:
	var horizontal_velocity: Vector2 = Vector2(_owner.velocity.x, _owner.velocity.z)
	if horizontal_velocity.length() < 0.5:
		return false
		
	var direction: Vector2 = horizontal_velocity.normalized()
	var feet_position: Vector3 = _owner.global_position
	var forward_position: Vector3 = feet_position + Vector3(direction.x, 0.0, direction.y) * climb_check_distance
	
	var ledge_voxel: Vector3i = Vector3i(roundi(forward_position.x), roundi(feet_position.y), roundi(forward_position.z))
	var above_ledge_voxel: Vector3i = ledge_voxel + Vector3i(0, 1, 0)
	
	var ledge_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(ledge_voxel)
	var above_type: TerrianData.TerrianType = chunk_manager.get_voxel_type_at(above_ledge_voxel)
	
	var ledge_is_solid_ground: bool = ledge_type != TerrianData.TerrianType.AIR and not TerrianData.is_water(ledge_type)
	var headroom_is_clear: bool = above_type == TerrianData.TerrianType.AIR
	
	if not (ledge_is_solid_ground and headroom_is_clear):
		return false

	# --- Smooth climb-out animation ---
	_climb_start = _owner.global_position
	_climb_end = Vector3(forward_position.x, float(ledge_voxel.y) + 1.0, forward_position.z)

	_climb_timer = 0.0
	_is_climbing_out = true
	_owner.velocity = Vector3.ZERO
	return true




#----------------
# Flying Gravity
#----------------
func apply_flying_gravity() -> void:
	var vertical_direction: float = float(_ascend_input) - float(_descend_input)
	_owner.velocity.y = vertical_direction * fly_up_down_speed


#----------------
# Gravity (RigidBody2D)
#----------------
func rigid2d_apply_gravity(state: PhysicsDirectBodyState2D) -> void:
	if is_on_floor:
		return
	
	var gravity_force: float = gravity_ascent if state.linear_velocity.y < 0.0 else gravity_descent
	state.linear_velocity.y += gravity_force * state.step


#----------------
# Gravity Presets
#----------------
func set_gravity(type: GravityType, custom_ascent: float = 0.0, custom_descent: float = 0.0) -> void:
	gravity_type = type
	
	if type == GravityType.CUSTOM:
		gravity_ascent = custom_ascent
		gravity_descent = custom_descent
		return
	
	gravity_ascent = presets[type][&"ascent"]
	gravity_descent = presets[type][&"descent"]
	
	is_flying = (type == GravityType.FLYING)


#----------------
# Jump
#----------------
func jump() -> void:
	if not (_owner is CharacterBody2D or _owner is CharacterBody3D):
		return
	
	_owner.velocity.y = jump_velocity


#----------------
# Fly Toggle
#----------------
func fly_toggle() -> void:
	is_flying = not is_flying
	
	if is_flying and (_owner is CharacterBody2D or _owner is CharacterBody3D):
		_owner.velocity.y = 0.0


#----------------
# Ascend / Descend
#----------------
func set_ascend(pressed: bool) -> void:
	_ascend_input = pressed


func set_descend(pressed: bool) -> void:
	_descend_input = pressed


#----------------
# Surface awareness (set by Player, via WaterDetector)
#----------------
func set_at_surface(is_at_surface: bool) -> void:
	_is_at_surface = is_at_surface
