#-###########################################
# Component Handler
#-###########################################

class_name ComponentHandler
extends Node

@export var component_data: Array[Resource]

var component_map: Dictionary = {}
var _active_components: Array[Component] = []


#----------------
# Ready
#----------------
func _ready() -> void:
	if not component_data:
		return
	
	for data in component_data:
		add_and_create_component(data)
	
	for component in component_map.values():
		component.ready()


#----------------
# Create Component
#----------------
func _create_component(data: ComponentData) -> Component:
	var component: Component = data.component.new(get_owner())
	
	if component is Component:
		_apply_data(component, data)
		return component
	
	return null


#----------------
# Apply ComponentData
#----------------
func _apply_data(component: Component, data: ComponentData) -> void:
	for property in data.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		
		if property.name == "component":
			continue
		
		if property.name in component:
			component.set(property.name, data.get(property.name))


#----------------
# Add + Create Component
#----------------
func add_and_create_component(data: ComponentData) -> Component:
	if not data or not data.component:
		push_error("ComponentHandler: Invalid component data")
		return null
	
	var component: Component = _create_component(data)
	
	if not component:
		push_error("ComponentHandler: Failed to create component: %s" % data.component.get_global_name())
		return null
	
	# Walk up inheritance chain to find direct child of Component
	var current: GDScript = data.component
	var parent: GDScript = current.get_base_script()
	
	while parent != null and parent.get_global_name() != &"Component":
		current = parent
		parent = parent.get_base_script()
	
	if not component_map.has(current):
		component_map[current] = component
	
	return component


#----------------
# Remove Component
#----------------
func remove_component(script: Script) -> void:
	if not has_component(script):
		return
	
	get_component(script).exit()
	component_map.erase(script)


#----------------
# Has Component
#----------------
func has_component(script: Script) -> bool:
	return component_map.has(script)


#----------------
# Get Component
#----------------
func get_component(script: Script) -> Component:
	return component_map.get(script)


#----------------
# Set Active
#----------------
func set_active(script: Script, active: bool) -> void:
	var component: Component = get_component(script)
	if not component:
		return
	
	if active and component not in _active_components:
		component.is_active = true
		_active_components.append(component)
	elif not active and component in _active_components:
		component.is_active = false
		_active_components.erase(component)


#----------------
# Process
#----------------
func _process(delta: float) -> void:
	for component in _active_components:
		component.process(delta)


#----------------
# Physics Process
#----------------
func _physics_process(delta: float) -> void:
	for component in _active_components:
		component.physics_process(delta)
	
	var handler_owner: Node = get_owner()
	if handler_owner is CharacterBody3D or handler_owner is CharacterBody2D:
		handler_owner.move_and_slide()


#----------------
# Input
#----------------
func _input(event: InputEvent) -> void:
	for component in _active_components:
		component.input(event)


#----------------
# Unhandled Input
#----------------
func _unhandled_input(event: InputEvent) -> void:
	for component in _active_components:
		component.unhandled_input(event)


#----------------
# Integrate Forces (2D)
#----------------
func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	for component in _active_components:
		component.integrate_forces(state)
