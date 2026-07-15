#-###########################################
# Gravity Component Data
#-###########################################
class_name GravityComponentData 
extends ComponentData

#-########## REQUIRED ################################
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Script", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var component: Script = preload("uid://ckkpqo3bx8v2t")
#-####################################################
@export_group("Stats")
@export_subgroup("Gravity")
@export var normal_ascending_gravity: float = 10.0
@export var normal_descending_gravity: float = 15.0
@export var swimming_ascending_gravity: float = 1.0
@export var swimming_descending_gravity: float = 2.0

@export_subgroup("Movement")
@export var jump_velocity: float = 4.0
@export var swim_vertical_speed: float = 3.0
@export var fly_up_down_speed: float = 4.0

@export_subgroup("Swimming Surface")
@export var surface_bob_speed: float = 1.5
@export var climb_check_distance: float = 0.6
