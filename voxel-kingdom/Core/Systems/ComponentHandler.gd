class_name ComponentHandler extends Node

@export var default_components: Array[Script]
var component_map: Dictionary = {}
var _active_components: Array[Component] = []

func _ready() -> void:
	if not default_components: return
	for script in default_components:
		add_and_create_component(script)
	for component in component_map.values():
		component.ready()

func _create_component(script: Script) -> Component:
	return script.new(get_owner())

func add_and_create_component(script: Script) -> Component:
	if not script:
		push_error("ComponentHandler: Invalid script")
		return null

	var component := _create_component(script)
	if not component:
		push_error("ComponentHandler: Failed to create component: %s" % script.get_global_name())
		return null

	# walk up to find the direct child of Component
	var current: GDScript = script
	var parent: GDScript = script.get_base_script()
	while parent != null and parent.get_global_name() != &"Component":
		current = parent
		parent = parent.get_base_script()

	if not component_map.has(current):
		component_map[current] = component

	return component

func remove_component(script: Script) -> void:
	if !has_component(script): return
	get_component(script).exit()
	component_map.erase(script)

func has_component(script: Script) -> bool:
	return component_map.has(script)

func get_component(script: Script) -> Component:
	return component_map.get(script)


func set_active(script: Script, active: bool) -> void:
	var component := get_component(script)
	if not component: return
	if active and component not in _active_components:
		component.is_active = true
		_active_components.append(component)
	elif not active and component in _active_components:
		component.is_active = false
		_active_components.erase(component)

# Component Life-Cycle
func _process(delta: float) -> void:
	for component in _active_components:
		component.process(delta)

func _physics_process(delta: float) -> void:
	for component in _active_components:
		component.physics_process(delta)
		var handler_owner: Node = get_owner()
		if handler_owner is CharacterBody3D:
			handler_owner.move_and_slide()

func _input(event: InputEvent) -> void:
	for component in _active_components:
		component.input(event)

func _unhandled_input(event: InputEvent) -> void:
	for component in _active_components:
		component.unhandled_input(event)

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	for component in _active_components:
		component.integrate_forces(state)
