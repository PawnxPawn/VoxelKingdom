#-###########################################
# Move Component
#-###########################################

class_name MoveComponent extends Component

signal velocity_zeroed


#----------------
# Move Modes
#----------------
enum move_mode {
	Walk,
	Run,
	Fly,
	FlyFast,
}


#----------------
# Resource Stats
#----------------
var max_speed: float = 150.0
var walk_speed: float = 60.0
var run_speed: float = 80.0
var fly_speed: float = 480.0
var fly_fast_speed: float = 900.0

var _input_direction: Vector2 = Vector2.ZERO

var speed: float = walk_speed
var slow_down_speed: float = 20.0

var current_velocity_2d: Vector2 = Vector2.ZERO
var current_velocity_3d: Vector3 = Vector3.ZERO

var move_mode_results: Dictionary = {
	move_mode.Walk: walk_speed,
	move_mode.Run: run_speed,
	move_mode.Fly: fly_speed,
	move_mode.FlyFast: fly_fast_speed,
}


#----------------
# Ready
#----------------
func ready() -> void:
	move_mode_results[move_mode.Walk] = walk_speed
	move_mode_results[move_mode.Run] = run_speed
	move_mode_results[move_mode.Fly] = fly_speed
	move_mode_results[move_mode.FlyFast] = fly_fast_speed


#----------------
# Physics Process
#----------------
func physics_process(_delta: float) -> void:
	if not is_active:
		return
	
	_move_char3d(_input_direction)


#----------------
# Input Direction
#----------------
func set_direction(direction: Vector2) -> void:
	_input_direction = direction


#----------------
# CharacterBody2D Movement
#----------------
func _move_char2d(direction: Vector2) -> void:
	var body: CharacterBody2D = _owner as CharacterBody2D
	if not body:
		return
	
	body.velocity.x = direction.x * speed
	current_velocity_2d = body.velocity
	
	if is_zero_approx(body.velocity.x):
		velocity_zeroed.emit()


#----------------
# CharacterBody3D Movement
#----------------
func _move_char3d(direction: Vector2) -> void:
	var body: CharacterBody3D = _owner as CharacterBody3D
	if not body:
		return
	
	var forward_direction: Vector3 = Vector3.ZERO
	
	if direction != Vector2.ZERO:
		var input_direction_3d: Vector3 = Vector3(direction.x, 0.0, direction.y)
		var facing_direction: Vector3 = _owner.global_transform.basis * input_direction_3d
		facing_direction = facing_direction.normalized()
		
		forward_direction = facing_direction * speed * _owner.get_physics_process_delta_time()
	else:
		var decel: float = speed * _owner.get_physics_process_delta_time()
		
		forward_direction = Vector3(
			move_toward(body.velocity.x, 0.0, decel),
			body.velocity.y,
			move_toward(body.velocity.z, 0.0, decel)
		)
	
	body.velocity = Vector3(
		forward_direction.x,
		body.velocity.y,
		forward_direction.z
	)
	
	current_velocity_3d = body.velocity
	
	if is_zero_approx(body.velocity.x) and is_zero_approx(body.velocity.z):
		velocity_zeroed.emit()
	
	body.move_and_slide()


#----------------
# Node2D Movement
#----------------
func _move_node2d(direction: Vector2) -> void:
	var body: Node2D = _owner as Node2D
	if not body:
		return
	
	body.position += direction * speed * body.get_process_delta_time()


#----------------
# Node3D Movement
#----------------
func _move_node3d(direction: Vector3) -> void:
	var body: Node3D = _owner as Node3D
	if not body:
		return
	
	body.position += direction * speed * body.get_process_delta_time()


#----------------
# Stop Movement
#----------------
func stop() -> void:
	var body: CharacterBody3D = _owner as CharacterBody3D
	if not body:
		return
	
	body.velocity.x = 0.0
	body.velocity.z = 0.0


#----------------
# Move Mode
#----------------
func set_move_mode(move_type: move_mode) -> void:
	if move_mode_results.has(move_type):
		speed = move_mode_results[move_type]
