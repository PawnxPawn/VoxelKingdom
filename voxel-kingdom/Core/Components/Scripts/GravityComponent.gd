#-###########################################
# Gravity Component
#-###########################################

class_name GravityComponent extends Component

signal grounded
signal left_floor

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

# Resource Exports
var normal_ascending_gravity: float = 10.0
var normal_descending_gravity: float = 15.0
var jump_velocity: float = 4.0
var fly_up_down_speed: float = 4.0

enum GravityType {
	NORMAL,
	CUSTOM,
}

var presets: Dictionary = {
	GravityType.NORMAL: {
		&"ascent": normal_ascending_gravity,
		&"descent": normal_descending_gravity,
	},
}


#----------------
# Init
#----------------
func _init(p_owner: Node) -> void:
	super(p_owner)
	
	if _owner is RigidBody2D:
		var body: RigidBody2D = _owner
		body.gravity_scale = 0.0
		body.can_sleep = false


#----------------
# Ready
#----------------
func ready() -> void:
	presets[GravityType.NORMAL][&"ascent"] = normal_ascending_gravity
	presets[GravityType.NORMAL][&"descent"] = normal_descending_gravity
	
	gravity_ascent = normal_ascending_gravity
	gravity_descent = normal_descending_gravity


#----------------
# Physics Process
#----------------
func physics_process(_delta: float) -> void:
	if _owner is CharacterBody2D or _owner is CharacterBody3D:
		apply_characterbody_gravity()


#----------------
# RigidBody2D Forces
#----------------
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
	if _owner.is_on_floor() and not is_flying:
		if not _was_on_floor:
			is_falling = false
			grounded.emit()
		
		_was_on_floor = true
		return
	
	if _was_on_floor:
		left_floor.emit()
	
	_was_on_floor = false
	
	if is_flying:
		var vertical_direction: float = float(_ascend_input) - float(_descend_input)
		_owner.velocity.y = vertical_direction * fly_up_down_speed
		return
	
	if _owner.velocity.y < 0.0:
		is_falling = true
	
	var gravity_force: float = gravity_ascent if _owner.velocity.y > 0.0 else gravity_descent
	_owner.velocity.y = max(
		_owner.velocity.y - gravity_force * _owner.get_physics_process_delta_time(),
		-max_fall_speed
	)


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
	if type == GravityType.CUSTOM:
		gravity_ascent = custom_ascent
		gravity_descent = custom_descent
		return
	
	gravity_ascent = presets[type][&"ascent"]
	gravity_descent = presets[type][&"descent"]


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
