extends State

var state_name:StringName = &"MoveState"

func enter() -> void:
	connect_components()


func exit() -> void:
	disconnect_components()

func connect_components() -> void:
	var input: InputSource = _handler.get_component(InputSource)
	var move: MoveComponent = _handler.get_component(MoveComponent)
	if move:
		_handler.set_active(MoveComponent, true)
		move.velocity_zeroed.connect(transition_to.bind(&"IdleState"))
		if input:
			input.moved.connect(move.set_direction)
			move.set_direction(_owner.input.direction)
			input.jump_pressed.connect(transition_to.bind(&"JumpState"))
			input.fly_pressed.connect(transition_to.bind(&"FlyState"))
			input.sprinting_pressed.connect(move.set_move_mode.bind(move.move_mode.Run))
			input.sprinting_released.connect(move.set_move_mode.bind(move.move_mode.Walk))


func disconnect_components() -> void:
	var input: InputSource = _handler.get_component(InputSource)
	var move: MoveComponent = _handler.get_component(MoveComponent)
	if move:
		_handler.set_active(MoveComponent, false)
		move.velocity_zeroed.disconnect(transition_to.bind(&"IdleState"))
		if input:
			input.moved.disconnect(move.set_direction)
			input.jump_pressed.disconnect(transition_to.bind(&"JumpState"))
			input.fly_pressed.disconnect(transition_to.bind(&"FlyState"))
			input.sprinting_pressed.disconnect(move.set_move_mode.bind(move.move_mode.Run))
			input.sprinting_released.disconnect(move.set_move_mode.bind(move.move_mode.Walk))
