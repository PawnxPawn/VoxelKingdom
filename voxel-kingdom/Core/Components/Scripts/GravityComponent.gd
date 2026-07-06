class_name GravityComponent extends Component

signal grounded
signal left_floor

const FLOOR_DOT_MIN: float = 0.99

var max_fall_speed: float = 40.0
var gravity_ascent: float = 15.0
var gravity_descent: float = 30.0

var is_on_floor: bool = false
var _was_on_floor: bool = false
var is_flying: bool = false
var _ascend_input: bool = false
var _descend_input: bool = false


#Resource Exports
var normal_ascending_gravity:float = 10.0
var normal_descending_gravity:float = 15.0
var jump_velocity: float = 4.0
var fly_up_down_speed:float = 4.0


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

func _init(p_owner: Node) -> void:
	super(p_owner)
	if _owner is RigidBody2D:
		var body := _owner as RigidBody2D
		body.gravity_scale = 0.0
		body.can_sleep = false


func ready() -> void:
	presets[GravityType.NORMAL][&"ascent"] = normal_ascending_gravity
	presets[GravityType.NORMAL][&"descent"] = normal_ascending_gravity
	gravity_ascent = normal_ascending_gravity
	gravity_descent = normal_descending_gravity
	


func physics_process(_delta: float) -> void:
	if _owner is CharacterBody2D or _owner is CharacterBody3D:
		apply_characterbody_gravity()


func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	is_on_floor_check(state)
	rigid2d_apply_gravity(state)


func is_on_floor_check(state: PhysicsDirectBodyState2D) -> void:
	_was_on_floor = is_on_floor
	is_on_floor = false
	
	for i in state.get_contact_count():
		var normal: float = state.get_contact_local_normal(i).dot(Vector2.UP)
		if normal > FLOOR_DOT_MIN:
			is_on_floor = true
			break
	
	if is_on_floor and not _was_on_floor:
		state.linear_velocity.y = 0.0
		grounded.emit()
	elif not is_on_floor and _was_on_floor:
		left_floor.emit()


func apply_characterbody_gravity() -> void:
	if _owner.is_on_floor() and not is_flying:
		if not _was_on_floor:
			grounded.emit()
		_was_on_floor = true
		return
	if _was_on_floor:
		left_floor.emit()
	_was_on_floor = false
	
	if is_flying:
		var direction: float = float(_ascend_input) - float(_descend_input)
		_owner.velocity.y = direction * fly_up_down_speed
		return
	
	var gravity: float = gravity_ascent if _owner.velocity.y > 0.0 else gravity_descent
	_owner.velocity.y = max(_owner.velocity.y - gravity * _owner.get_physics_process_delta_time(), -max_fall_speed)


func rigid2d_apply_gravity(state:PhysicsDirectBodyState2D) -> void:
	if is_on_floor: return
	var gravity: float = gravity_ascent if state.linear_velocity.y < 0.0 else gravity_descent
	state.linear_velocity.y += gravity * state.step


func set_gravity(type: GravityType, custom_ascent: float = 0.0, custom_descent: float = 0.0) -> void:
	if type == GravityType.CUSTOM:
		gravity_ascent = custom_ascent
		gravity_descent = custom_descent
		return
	gravity_ascent = presets[type][&"ascent"]
	gravity_descent = presets[type][&"descent"]


func jump() -> void:
	if not (_owner is CharacterBody2D or _owner is CharacterBody3D): return
	_owner.velocity.y = jump_velocity


func fly_toggle() -> void:
	is_flying = !is_flying
	if is_flying and (_owner is CharacterBody2D or _owner is CharacterBody3D):
		_owner.velocity.y = 0.0


func set_ascend(pressed: bool) -> void:
	_ascend_input = pressed


func set_descend(pressed: bool) -> void:
	_descend_input = pressed
