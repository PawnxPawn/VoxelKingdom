class_name CameraComponentData extends ComponentData

@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Script", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var component: Script = preload("uid://ch5wra7y1gllq")

@export_group("Stats")
@export_range(60.0, 120.0, 0.1) var fov: float = 90.0
