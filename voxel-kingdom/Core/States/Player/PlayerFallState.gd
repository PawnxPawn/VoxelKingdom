extends State

var _input: InputSource = null
var _move: MoveComponent = null
var _gravity: GravityComponent = null

func enter() -> void:
	connect_components()


func connect_components() -> void:
	_input = _handler.get_component(InputSource)
	_move = _handler.get_component(MoveComponent)
	_gravity = _handler.get_component(GravityComponent)
	
	if _move:
		_handler.set_active(MoveComponent, true)
		if _input:
			_input.moved.connect(_move.set_direction)
			_move.set_direction(_input.direction)
			_input.fly_pressed.connect(transition_to.bind(&"FlyState"))


func process_physics(_delta: float) -> void:
	if not _gravity: return
	if _gravity.is_on_floor:
		change_state_logic()


func change_state_logic() -> void:
	if not _move: return
	if _move.current_velocity.is_zero_approx():
		transition_to(&"IdleState")
	else:
		transition_to(&"MoveState")

func disconnect_components() -> void:
	_input.moved.connect(_move.set_direction)
	_move.set_direction(_input.direction)
	_input.fly_pressed.connect(transition_to.bind(&"FlyState"))


func exit() -> void:
	disconnect_components()
