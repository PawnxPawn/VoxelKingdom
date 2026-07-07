class_name PlayerInput extends InputSource

const PIXEL_SCALE:float = 0.002

#Resource Exports
var mouse_sensitivity: Vector2 = Vector2(1.0, 0.50)

var direction: Vector2 = Vector2.ZERO

var _look_direction: Vector2 = Vector2.ZERO
var _new_look_direction: Vector2 = Vector2.ZERO


func ready() -> void:
	change_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func process(_delta: float) -> void:
	_look_direction = _new_look_direction
	_new_look_direction = Vector2.ZERO
	_process_move()
	_process_input()


func _process_move() -> void:
	var new_direction: Vector2 = Input.get_vector(&"Move_Left",&"Move_Right", &"Move_Forward", &"Move_Backward")
	if new_direction != direction:
		direction = new_direction
		moved.emit(direction)


func _process_input() -> void:
	if Input.is_action_just_pressed(&"Jump"):
		jump_pressed.emit()
	if Input.is_action_just_released(&"Jump"):
		jump_released.emit()
	
	if Input.is_action_just_pressed(&"Sprint"):
		sprinting_pressed.emit()
	if Input.is_action_just_released(&"Sprint"):
		sprinting_released.emit()
	
	if Input.is_action_just_pressed(&"Interact"):
		interacted_pressed.emit()
	
	if Input.is_action_just_pressed(&"Inventory"):
		inventory_pressed.emit()
	
	if Input.is_action_just_pressed(&"Fly"):
		fly_pressed.emit()
	
	if Input.is_action_just_pressed(&"Crouch"):
		crouch_pressed.emit()
	if Input.is_action_just_released(&"Crouch"):
		crouch_released.emit()
	
	if Input.is_action_just_pressed("Add_Block"):
		add_block_pressed.emit()
	if Input.is_action_just_pressed("Remove_Block"):
		remove_block_pressed.emit()



func input(event: InputEvent) -> void:
	if event.is_action_pressed("Add_Block"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#TODO: DELETE after pause menu is added
	if event.is_action_pressed(&"ui_cancel") and not OS.has_feature("web"):
		_owner.get_tree().quit()
	if event is InputEventMouseMotion:
		var look_direction = (event.screen_relative * PIXEL_SCALE) * mouse_sensitivity
		look_direction_changed.emit(look_direction)
		


func change_mouse_mode(mouse_mode) -> void:
	Input.mouse_mode = mouse_mode
