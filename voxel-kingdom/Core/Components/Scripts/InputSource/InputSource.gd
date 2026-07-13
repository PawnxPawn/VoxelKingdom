#-###########################################
# Input Source Base
#-###########################################

@abstract class_name InputSource extends Component

signal moved(direction: Vector2)
signal look_direction_changed(direction: Vector2)
signal jump_pressed
signal jump_released
signal crouch_pressed
signal crouch_released
signal sprinting_pressed
signal sprinting_released
signal interacted_pressed
signal inventory_pressed
signal fly_pressed
signal add_block_pressed
signal remove_block_pressed
signal item_switched_up
signal item_switched_down
