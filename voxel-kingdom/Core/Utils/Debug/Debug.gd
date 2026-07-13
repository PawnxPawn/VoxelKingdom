#-###########################################
# Debug Overlay
#-###########################################

class_name Debug
extends CanvasLayer

enum { STATS, BUTTONS, OTHER }

const DEBUG_SETTINGS = preload("uid://cgi4xbq515n1v")

var debug_setting_instant: PanelContainer

var labels: VBoxContainer
var buttons: GridContainer
var debug_controls: VBoxContainer

var frame_tracker: int = 0
var properties: Dictionary = {}


#----------------
# Ready
#----------------
func _ready() -> void:
	visible = false
	_setup_debugger_nodes()


#----------------
# Setup Debugger Nodes
#----------------
func _setup_debugger_nodes() -> void:
	var panel_container: PanelContainer = PanelContainer.new()
	add_child(panel_container)
	
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override(&"separation", 25)
	panel_container.add_child(container)
	
	debug_setting_instant = DEBUG_SETTINGS.instantiate()
	add_child(debug_setting_instant)
	
	debug_controls = VBoxContainer.new()
	container.add_child(debug_controls)
	
	var debug_settings_button: Button = Button.new()
	debug_settings_button.text = "Debug Settings"
	debug_settings_button.pressed.connect(
		func(): debug_setting_instant.visible = not debug_setting_instant.visible
	)
	container.add_child(debug_settings_button)
	
	var hseparator: HSeparator = HSeparator.new()
	var style: StyleBoxLine = StyleBoxLine.new()
	style.thickness = 8
	style.color = Color(1.0, 1.0, 1.0, 1.0)
	hseparator.add_theme_stylebox_override(&"Debug", style)
	container.add_child(hseparator)
	
	labels = VBoxContainer.new()
	container.add_child(labels)
	
	buttons = GridContainer.new()
	buttons.columns = 2
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(buttons)


#----------------
# Input Toggle
#----------------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"Debug"):
		visible = not visible
		get_viewport().set_input_as_handled()


#----------------
# Process
#----------------
func _process(_delta: float) -> void:
	pass
	# frame_tracker += 1


#----------------
# Add Debug Label
#----------------
func add_debug_label(id: StringName, value: Variant, frames_before_updating: int = 1) -> void:
	if properties.has(id):
		if frame_tracker % frames_before_updating == 0:
			var target: Label = properties[id]
			target.text = _get_id_value_string(id, value)
		return
	
	var property: Label = Label.new()
	property.name = id
	property.text = _get_id_value_string(id, value)
	property.add_theme_font_size_override(&"font_size", 25)
	labels.add_child(property)
	
	properties[id] = property
	_add_to_settings(id, property, STATS)


#----------------
# Add Debug Button
#----------------
func add_debug_button(id: StringName, connection: Callable, text: String = "") -> void:
	if properties.has(id):
		return
	
	var button: Button = Button.new()
	button.name = id
	button.text = text if text else str(id)
	button.add_theme_font_size_override(&"font_size", 25)
	button.pressed.connect(connection)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons.add_child(button)
	
	properties[id] = button
	_add_to_settings(id, button, BUTTONS)


#----------------
# Remove Debug Property
#----------------
func remove_debug_property(id: StringName) -> void:
	if not properties.has(id):
		return
	
	properties[id].queue_free()
	properties.erase(id)


#----------------
# Format ID/Value
#----------------
func _get_id_value_string(id: StringName, value: Variant) -> String:
	return "%s: %s" % [id, str(value)]


#----------------
# Add to Settings Panel
#----------------
func _add_to_settings(id: StringName, node: Node, type: Variant) -> void:
	var location: GridContainer = _get_location(type)
	
	var check_box: CheckBox = CheckBox.new()
	check_box.name = id
	check_box.text = id
	check_box.add_theme_font_size_override(&"font_size", 40)
	check_box.button_pressed = node.visible
	location.add_child(check_box)
	
	check_box.button_down.connect(_check_box_pressed.bind(node))


#----------------
# Remove from Settings Panel
#----------------
func _remove_from_settings(id: StringName, type: Variant) -> void:
	var location: GridContainer = _get_location(type)
	
	if location.get_children().has(id):
		var node: Node = location.find_child(id)
		node.queue_free()


#----------------
# Checkbox Toggle
#----------------
func _check_box_pressed(node: Node) -> void:
	node.visible = not node.visible


#----------------
# Get Settings Location
#----------------
func _get_location(type: Variant) -> GridContainer:
	var location_container: GridContainer = null
	
	match type:
		STATS:
			location_container = debug_setting_instant.labels_container
		BUTTONS:
			location_container = debug_setting_instant.button_container
		_:
			location_container = debug_setting_instant.other_container
	
	return location_container
