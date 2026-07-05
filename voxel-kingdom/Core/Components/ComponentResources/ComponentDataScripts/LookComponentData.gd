class_name LookComponentData extends ComponentData

@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Script", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var component: Script = preload("uid://bspc0ucuc08ip")

@export_group("Stats")
@export_range(0, 360, 0.1, "radians_as_degrees") 
var pitch_clamp_top: float = deg_to_rad(89.0)
@export_range(0, 360, 0.1, "radians_as_degrees") 
var pitch_clamp_bottom: float = deg_to_rad(-89.0)
