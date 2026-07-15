#-###########################################
# Swim State
#-###########################################

extends State

var state_name: StringName = &"SwimState"

var _input: InputSource = null
var _move: MoveComponent = null
var _gravity: GravityComponent = null


#----------------
# Lifecycle
#----------------
func enter() -> void:
	connect_components()
	if _move:
		_move.set_move_mode(_move.move_mode.Swim)
	if _gravity:
		_gravity.set_gravity(_gravity.GravityType.WATER)
	if _input and _gravity:
		_gravity.set_ascend(_input.is_jump_held)


func physics_process(_delta: float) -> void:
	if _input and _gravity:
		_gravity.set_ascend(_input.is_jump_held)


func exit() -> void:
	_move.set_move_mode(_move.move_mode.Walk)
	_gravity.set_gravity(_gravity.GravityType.NORMAL)
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
			
			_input.sprinting_pressed.connect(_move.set_move_mode.bind(_move.move_mode.SwimFast))
			_input.sprinting_released.connect(_move.set_move_mode.bind(_move.move_mode.Swim))
			
	
	if _input:
		_input.jump_pressed.connect(_gravity.set_ascend.bind(true))
		_input.jump_released.connect(_gravity.set_ascend.bind(false))
		
		_input.crouch_pressed.connect(_gravity.set_descend.bind(true))
		_input.crouch_released.connect(_gravity.set_descend.bind(false))
		
		_input.fly_pressed.connect(transition_to.bind(&"FlyState"))
	
	if _gravity:
		_gravity.set_gravity(_gravity.GravityType.WATER)
		_gravity.climbed_out.connect(_on_climbed_out)

#----------------
# Disconnect
#----------------

func disconnect_components() -> void:
	if _move:
		_move.stop()
		_handler.set_active(MoveComponent, false)
		
		if _input:
			_input.moved.disconnect(_move.set_direction)
			_input.sprinting_pressed.disconnect(_move.set_move_mode.bind(_move.move_mode.SwimFast))
			_input.sprinting_released.disconnect(_move.set_move_mode.bind(_move.move_mode.Swim))
	
	if _gravity:
		_gravity.set_ascend(false)
		_gravity.set_descend(false)
		_gravity.set_gravity(_gravity.GravityType.NORMAL)
		_gravity.climbed_out.disconnect(_on_climbed_out)
	
	if _input:
		_input.jump_pressed.disconnect(_gravity.set_ascend.bind(true))
		_input.jump_released.disconnect(_gravity.set_ascend.bind(false))
		
		_input.crouch_pressed.disconnect(_gravity.set_descend.bind(true))
		_input.crouch_released.disconnect(_gravity.set_descend.bind(false))
		
		_input.fly_pressed.disconnect(transition_to.bind(&"FlyState"))

#-------------------
# Calls
#-------------------

func _on_climbed_out() -> void:
	if _owner.input and _owner.input.movement_direction != Vector2.ZERO:
		transition_to(&"MoveState")
	else:
		transition_to(&"IdleState")
