class_name StateMachine extends Node

signal state_changed(from_state: State, to_state: State)

@export var state_scripts: Array[GDScript]

var _states: Dictionary = {}
var _current_state: State = null
var _last_state: State = null
var _is_transitioning: bool = false

var current_state: State:
	get: return _current_state

var last_state: State:
	get: return _last_state


func init(component_handler: ComponentHandler) -> void:
	for script in state_scripts:
		var state = script.new() as State
		_states[state.state_name] = state
		state._setup(self, get_owner(), component_handler)
	
	if _states.is_empty(): return
	var start = _states.keys()[0] as StringName
	change_state(start)


func change_state(state_name: StringName) -> void:
	if _is_transitioning:
		push_warning("StateMachine: change_state('%s') called during a transition." % state_name)
		return
	
	if not _states.has(state_name):
		push_error("StateMachine: state '%s' not found. CurrentState: %s" % [state_name, current_state.state_name])
		return
	var new_state: State = _states[state_name]
	_is_transitioning = true
	
	if _current_state:
		_current_state.exit()
	
	_last_state = _current_state
	_current_state = new_state
	_is_transitioning = false
	
	
	state_changed.emit(_last_state, _current_state)
	_current_state.enter()

#Thoughts: Should this be implemented?
#func _input(event: InputEvent) -> void:
	#if _current_state:
		#_current_state.process_input(event)


#func _unhandled_input(event: InputEvent) -> void:
	#if _current_state:
		#_current_state.process_input(event)


func _process(delta: float) -> void:
	if _current_state:
		_current_state.process_frame(delta)


func _physics_process(delta: float) -> void:
	if _current_state:
		_current_state.process_physics(delta)
