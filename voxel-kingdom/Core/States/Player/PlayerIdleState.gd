#-###########################################
# Idle State
#-###########################################

extends State

var state_name: StringName = &"IdleState"

var _input: InputSource = null


#----------------
# Lifecycle
#----------------
func enter() -> void:
	connect_components()


func exit() -> void:
	disconnect_components()


#----------------
# Movement Callback
#----------------
func _moved(_direction: Vector2) -> void:
	transition_to(&"MoveState")


#----------------
# Connect
#----------------
func connect_components() -> void:
	_input = _handler.get_component(InputSource)
	
	if _input:
		_input.moved.connect(_moved)
		_input.jump_pressed.connect(transition_to.bind(&"JumpState"))
		_input.fly_pressed.connect(transition_to.bind(&"FlyState"))


#----------------
# Disconnect
#----------------
func disconnect_components() -> void:
	if _input:
		_input.moved.disconnect(_moved)
		_input.jump_pressed.disconnect(transition_to.bind(&"JumpState"))
		_input.fly_pressed.disconnect(transition_to.bind(&"FlyState"))
