#-###########################################
# Player Move State
#-###########################################

extends State

var state_name: StringName = &"MoveState"

#-##############################
# Components
#-##############################

var _input: InputSource = null
var _move: MoveComponent = null


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
	
	if _move:
		_handler.set_active(MoveComponent, true)
		
		_move.velocity_zeroed.connect(transition_to.bind(&"IdleState"))
		
		if _input:
			_input.moved.connect(_move.set_direction)
			_move.set_direction(_input.movement_direction)
			
			_input.jump_pressed.connect(transition_to.bind(&"JumpState"))
			_input.fly_pressed.connect(transition_to.bind(&"FlyState"))
			
			_input.sprinting_pressed.connect(_move.set_move_mode.bind(_move.move_mode.Run))
			_input.sprinting_released.connect(_move.set_move_mode.bind(_move.move_mode.Walk))


#----------------
# Disconnect
#----------------
func disconnect_components() -> void:
	if _move:
		_move.stop()
		_handler.set_active(MoveComponent, false)
		
		_move.velocity_zeroed.disconnect(transition_to.bind(&"IdleState"))
		
		if _input:
			_input.moved.disconnect(_move.set_direction)
			
			_input.jump_pressed.disconnect(transition_to.bind(&"JumpState"))
			_input.fly_pressed.disconnect(transition_to.bind(&"FlyState"))
			
			_input.sprinting_pressed.disconnect(_move.set_move_mode.bind(_move.move_mode.Run))
			_input.sprinting_released.disconnect(_move.set_move_mode.bind(_move.move_mode.Walk))
