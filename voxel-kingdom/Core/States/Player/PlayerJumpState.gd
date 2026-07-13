#-###########################################
# Jump State
#-###########################################

extends State

var state_name: StringName = &"JumpState"

var _input: InputSource = null
var _move: MoveComponent = null
var _gravity: GravityComponent = null


#----------------
# Lifecycle
#----------------
func enter() -> void:
	connect_components()
	_gravity.jump()


func exit() -> void:
	disconnect_components()


#----------------
# Grounded Callback
#----------------
func _on_grounded() -> void:
	if _input and _input.movement_direction != Vector2.ZERO:
		transition_to(&"MoveState")
	else:
		transition_to(&"IdleState")


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
	
	if _input:
		_input.fly_pressed.connect(transition_to.bind(&"FlyState"))
	
	if _gravity:
		_gravity.grounded.connect(_on_grounded)
		# If falling logic is needed later:
		# if _gravity.is_falling:
		#     transition_to(&"FallState")


#----------------
# Disconnect
#----------------
func disconnect_components() -> void:
	if _move:
		_move.stop()
		_handler.set_active(MoveComponent, false)
		
		if _input:
			_input.moved.disconnect(_move.set_direction)
	
	if _input:
		_input.fly_pressed.disconnect(transition_to.bind(&"FlyState"))
		
	if _gravity:
		_gravity.grounded.disconnect(_on_grounded)
