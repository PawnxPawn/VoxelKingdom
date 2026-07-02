class_name MoveComponent extends Component

signal velocity_zeroed

enum move_mode {
	Walk,
	Run,
	Fly,
}

const MAX_SPEED: float = 150.0

var _input_direction: Vector2 = Vector2.ZERO

var speed: float = 60.0
var slow_down_speed: float = 20.0

var move_mode_results: Dictionary = {
	move_mode.Walk: 60.0,
	move_mode.Run: 80.0,
	move_mode.Fly: 120.0,
}


func physics_process(_delta: float) -> void:
	if not is_active: return
	_move_char3d(_input_direction)


func set_direction(direction: Vector2) -> void:
	_input_direction = direction


func _move_char2d(direction: Vector2) -> void:
	var body := _owner as CharacterBody2D
	if not body: return
	body.velocity.x = direction.x * speed
	if is_zero_approx(body.velocity.x):
		velocity_zeroed.emit()


func _move_char3d(direction: Vector2) -> void:
	var body: CharacterBody3D = _owner as CharacterBody3D
	var forward_direction: Vector3
	
	if direction:
		var input_dir: Vector3 = Vector3(direction.x, 0, direction.y)
		var facing_direction: Vector3 = _owner.global_transform.basis * input_dir
		facing_direction = facing_direction.normalized()
		forward_direction = facing_direction * speed * _owner.get_physics_process_delta_time()
	else:
		forward_direction.x = move_toward(body.velocity.x, 0, speed)
		forward_direction.z = move_toward(body.velocity.z, 0, speed)
	
	body.velocity = Vector3(forward_direction.x, body.velocity.y, forward_direction.z)
	
	if is_zero_approx(body.velocity.x) and is_zero_approx(body.velocity.z):
		velocity_zeroed.emit()
	
	body.move_and_slide()


func _move_node2d(direction: Vector2) -> void:
	var body := _owner as Node2D
	if not body: return
	body.position += direction * speed * body.get_process_delta_time()


func _move_node3d(direction:Vector3):
	var body := _owner as Node3D
	if not body: return
	body.position += direction * speed * body.get_process_delta_time()





#func integrate_forces2D(state: PhysicsDirectBodyState2D) -> void:
	#if signf(_direction) != signf(_last_direction) and _last_direction != 0.0:
		#state.linear_velocity.x = 0.0
#
	#_last_direction = _direction
#
	#if _direction != 0.0:
		#if absf(state.linear_velocity.x) < MAX_SPEED:
			#state.linear_velocity.x += _direction * speedvv
		#return
#
	#if absf(state.linear_velocity.x) > 1.0:
		#var brake := signf(-state.linear_velocity.x) * slow_down_speed
		#if absf(brake) >= absf(state.linear_velocity.x):
			#state.linear_velocity.x = 0.0
			#velocity_zeroed.emit()
		#else:
			#state.linear_velocity.x += brake
		#return
#
	#state.linear_velocity.x = 0.0
	#velocity_zeroed.emit()

#TODO: Add integrate_forces3D


func set_move_mode(move_type: move_mode) -> void:
	if move_mode_results.has(move_type):
		speed = move_mode_results[move_type]
