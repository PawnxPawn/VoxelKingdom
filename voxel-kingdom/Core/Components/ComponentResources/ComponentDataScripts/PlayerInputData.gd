class_name PlayerInputData extends ComponentData

@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Script", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var component: Script = preload("uid://bgsj8gw2nmanw")

@export_group("Stats")
@export var mouse_sensitivity:Vector2 = Vector2(1.0, 0.50)
