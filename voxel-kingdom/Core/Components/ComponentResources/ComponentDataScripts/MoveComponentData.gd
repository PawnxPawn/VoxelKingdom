#-###########################################
# Move Component Data
#-###########################################

class_name MoveComponentData extends ComponentData

#-########## REQUIRED ################################
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Script", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var component: Script = preload("uid://chvfc2ghjnp2v")
#-####################################################

@export_group("Stats")
@export var max_speed: float = 150.0
@export var walk_speed: float = 60.0
@export var run_speed: float = 80.0
@export var fly_speed: float = 480.0
@export var fly_fast_speed: float = 900.0
