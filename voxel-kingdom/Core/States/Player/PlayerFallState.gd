#-###########################################
# Fall State
#-###########################################

extends State

var state_name: StringName = &"FallState"

var _input: InputSource = null
var _move: MoveComponent = null
var _gravity: GravityComponent = null


#----------------
# Lifecycle
#----------------
func enter() -> void:
	connect_components()


func exit() -> void:
	disconnect_components()


#----------------
# Connect
#----------------
func connect_components() -> void:
	_input = _handler.get_component(InputSource)
	_move = _handler.get_component(MoveComponent)
	_gravity = _handler.get_component(GravityComponent)
	
	if _move:
		_handler.set_active(MoveComponent, true)
		
		if _input:
			_input.moved.connect(_move.set_direction)
			_move.set_direction(_input.movement_direction)
			
			_input.fly_pressed.connect(transition_to.bind(&"FlyState"))


#----------------
# Physics
#----------------
func process_physics(_delta: float) -> void:
	if not _gravity:
		return
	
	if _gravity.is_on_floor:
		change_state_logic()


#----------------
# Change State Logic
#----------------
func change_state_logic() -> void:
	if not _move:
		return
	
	if _move.current_velocity_3d.is_zero_approx():
		transition_to(&"IdleState")
	else:
		transition_to(&"MoveState")


#----------------
# Disconnect
#----------------
func disconnect_components() -> void:
	if _input and _move:
		_input.moved.disconnect(_move.set_direction)
		_input.fly_pressed.disconnect(transition_to.bind(&"FlyState"))
	
	if _move:
		_handler.set_active(MoveComponent, false)
