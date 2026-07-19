#-###########################################
# Player Input Component
#-###########################################

class_name PlayerInput extends InputSource

const PIXEL_SCALE: float = 0.002

# Resource Exports
var mouse_sensitivity: Vector2 = Vector2(1.0, 0.50)
#-------------- End Resources ---------------------

var movement_direction: Vector2 = Vector2.ZERO

var allow_mouse: bool = false
var is_place_mode_active: bool = false
var is_jump_held: bool = false


var look_direction: Vector2 = Vector2.ZERO
var pending_look_direction: Vector2 = Vector2.ZERO


#----------------
# Lifecycle
#----------------

func process(_delta: float) -> void:
	look_direction = pending_look_direction
	pending_look_direction = Vector2.ZERO
	
	_process_movement_input()
	_process_jump_input()
	_process_sprint_input()
	_process_crouch_input()
	_process_interaction_input()
	_process_block_input()
	_process_item_switch_input()


#----------------
# Movement Input
#----------------
func _process_movement_input() -> void:
	var new_movement_direction: Vector2 = Input.get_vector(
		&"Move_Left",
		&"Move_Right",
		&"Move_Forward",
		&"Move_Backward"
	)
	
	if new_movement_direction != movement_direction:
		movement_direction = new_movement_direction
		moved.emit(movement_direction)


#----------------
# Jump Input
#----------------
func _process_jump_input() -> void:
	if Input.is_action_just_pressed(&"Jump"):
		jump_pressed.emit()
		
	if Input.is_action_just_released(&"Jump"):
		jump_released.emit()


#----------------
# Sprint Input
#----------------
func _process_sprint_input() -> void:
	if Input.is_action_just_pressed(&"Sprint"):
		is_jump_held = true
		sprinting_pressed.emit()
		
	if Input.is_action_just_released(&"Sprint"):
		is_jump_held = false
		sprinting_released.emit()


#----------------
# Crouch Input
#----------------
func _process_crouch_input() -> void:
	if Input.is_action_just_pressed(&"Crouch"):
		crouch_pressed.emit()
		
	if Input.is_action_just_released(&"Crouch"):
		crouch_released.emit()


#----------------
# Interaction Input
#----------------
func _process_interaction_input() -> void:
	if Input.is_action_just_pressed(&"Interact"):
		interacted_pressed.emit()
		
	if Input.is_action_just_pressed(&"Inventory"):
		inventory_pressed.emit()
		
	if Input.is_action_just_pressed(&"Fly"):
		fly_pressed.emit()


#----------------
# Block Input
#----------------
func _process_block_input() -> void:
	if Input.is_action_just_pressed(&"Add_Block"):
		if is_place_mode_active:
			add_block_pressed.emit()
		else:
			remove_block_pressed.emit()
			
	if Input.is_action_just_pressed(&"Change_Mode"):
		is_place_mode_active = not is_place_mode_active
		place_mode_changed.emit()


#----------------
# Item Switching Input
#----------------
func _process_item_switch_input() -> void:
	if Input.is_action_just_pressed(&"InventorySlot1"):
		item_slot_pressed.emit(0)
	if Input.is_action_just_pressed(&"InventorySlot2"):
		item_slot_pressed.emit(1)
	if Input.is_action_just_pressed(&"InventorySlot3"):
		item_slot_pressed.emit(2)
	if Input.is_action_just_pressed(&"InventorySlot4"):
		item_slot_pressed.emit(3)
	if Input.is_action_just_pressed(&"InventorySlot5"):
		item_slot_pressed.emit(4)
	if Input.is_action_just_pressed(&"InventorySlot6"):
		item_slot_pressed.emit(5)
	if Input.is_action_just_pressed(&"InventorySlot7"):
		item_slot_pressed.emit(6)
	if Input.is_action_just_pressed(&"InventorySlot8"):
		item_slot_pressed.emit(7)
	if Input.is_action_just_pressed(&"InventorySlot9"):
		item_slot_pressed.emit(8)
	if Input.is_action_just_pressed(&"InventorySlot0"):
		item_slot_pressed.emit(9)


#----------------
# Raw Input Events
#----------------
func input(event: InputEvent) -> void:
	if event.is_action_pressed(&"Add_Block"):
		if not allow_mouse:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# TODO: DELETE after pause menu is added
	if event.is_action_pressed(&"ui_cancel") and not OS.has_feature("web"):
		_owner.get_tree().quit()
		
	if event is InputEventMouseMotion:
		var mouse_motion_event: InputEventMouseMotion = event
		var computed_look_direction: Vector2 = (mouse_motion_event.screen_relative * PIXEL_SCALE) * mouse_sensitivity
		look_direction_changed.emit(computed_look_direction)
		
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		
		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button_event.pressed:
			item_switched.emit(1)
			
		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button_event.pressed:
			item_switched.emit(-1)


#----------------
# Mouse Mode
#----------------
func change_mouse_mode(mouse_mode: int) -> void:
	Input.mouse_mode = mouse_mode as Input.MouseMode
