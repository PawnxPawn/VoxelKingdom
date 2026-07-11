extends State
var state_name: StringName = &"FlyState"

var _input: InputSource
var _move: MoveComponent
var _gravity: GravityComponent

func enter() -> void:
	connect_components()
	_gravity.fly_toggle()
	_move.set_move_mode(_move.move_mode.Fly)


func exit() -> void:
	_gravity.fly_toggle()
	_move.set_move_mode(_move.move_mode.Walk)
	disconnect_components()


func _on_fly_toggled() -> void:
	if _input and _input.direction != Vector2.ZERO:
		transition_to("MoveState")
	else:
		transition_to("IdleState")


func connect_components() -> void:
	_input = _handler.get_component(InputSource)
	_move = _handler.get_component(MoveComponent)
	_gravity = _handler.get_component(GravityComponent)
	
	if _move:
		_handler.set_active(MoveComponent, true)
		if _input:
			_input.moved.connect(_move.set_direction)
			_move.set_direction(_owner.input.direction)
			_input.sprinting_pressed.connect(_move.set_move_mode.bind(_move.move_mode.FlyFast))
			_input.sprinting_released.connect(_move.set_move_mode.bind(_move.move_mode.Fly))
	
	if _input:
		_input.jump_pressed.connect(_gravity.set_ascend.bind(true))
		_input.jump_released.connect(_gravity.set_ascend.bind(false))
		_input.crouch_pressed.connect(_gravity.set_descend.bind(true))
		_input.crouch_released.connect(_gravity.set_descend.bind(false))
		_input.fly_pressed.connect(_on_fly_toggled)


func disconnect_components() -> void:
	if _move:
		_move.stop()
		_handler.set_active(MoveComponent, false)
		if _input:
			_input.moved.disconnect(_move.set_direction)
			_input.sprinting_pressed.disconnect(_move.set_move_mode.bind(_move.move_mode.FlyFast))
			_input.sprinting_released.disconnect(_move.set_move_mode.bind(_move.move_mode.Fly))
	
	if _gravity:
		_gravity.set_ascend(false)
		_gravity.set_descend(false)
	
	if _input:
		_input.jump_pressed.disconnect(_gravity.set_ascend.bind(true))
		_input.jump_released.disconnect(_gravity.set_ascend.bind(false))
		_input.crouch_pressed.disconnect(_gravity.set_descend.bind(true))
		_input.crouch_released.disconnect(_gravity.set_descend.bind(false))
		_input.fly_pressed.disconnect(_on_fly_toggled)
