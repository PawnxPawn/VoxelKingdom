@abstract class_name State extends RefCounted

var _sm: StateMachine
var _owner: Node
var _handler: ComponentHandler

func _setup(sm: StateMachine, parent: Node, handler: ComponentHandler) -> void:
	_sm = sm
	_owner = parent
	_handler = handler


@abstract func enter() -> void


@abstract func exit() -> void


func process_input(_event: InputEvent) -> void:
	pass


func process_frame(_delta: float) -> void:
	pass


func process_physics(_delta: float) -> void:
	pass


func transition_to(name: StringName) -> void:
	_sm.change_state(name)
