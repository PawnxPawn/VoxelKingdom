# JumpState
extends State
var state_name: StringName = &"JumpState"

var _input: InputSource
var _move: MoveComponent
var _gravity: GravityComponent

func enter() -> void:
	connect_components()
	_gravity.jump()

func exit() -> void:
	disconnect_components()

func _on_grounded() -> void:
	if _owner.input and _owner.input.direction != Vector2.ZERO:
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

	if _gravity:
		_gravity.grounded.connect(_on_grounded)

func disconnect_components() -> void:
	if _move:
		_handler.set_active(MoveComponent, false)
		if _input:
			_input.moved.disconnect(_move.set_direction)

	if _gravity:
		_gravity.grounded.disconnect(_on_grounded)
