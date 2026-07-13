#-###########################################
# Camera Component
#-###########################################

class_name CameraComponent extends Component

signal camera_entered

var camera: Camera3D

const MIN_FOV: float = 60.0
const MAX_FOV: float = 120.0

# Resource Exports
var fov: float = 90.0


#----------------
# Lifecycle
#----------------
func ready() -> void:
	camera = Camera3D.new()
	camera.name = &"CameraComponent"
	_owner.add_child.call_deferred(camera)
	camera.fov = fov


#----------------
# Camera Path
#----------------
func get_camera_path() -> NodePath:
	return camera.get_path()


#----------------
# FOV
#----------------
func set_fov(new_fov: float) -> void:
	camera.fov = clamp(new_fov, MIN_FOV, MAX_FOV)


#----------------
# Position
#----------------
func set_position(new_position: Vector3) -> void:
	camera.position = new_position


#----------------
# Cull Layers
#----------------
func set_camera_cull_layers(layers: Dictionary) -> void:
	for layer_index in layers.keys():
		var layer_enabled: bool = layers[layer_index]
		camera.set_cull_mask_value(layer_index, layer_enabled)


#----------------
# Rotation
#----------------
func set_rotation(pitch: float, yaw: float, roll: float) -> void:
	camera.rotation = Vector3(pitch, 0.0, roll)
	_owner.rotation.y = yaw


#----------------
# Make Current
#----------------
func make_current() -> void:
	if camera.current:
		return
	
	camera.make_current()


#----------------
# Exit
#----------------
func exit() -> void:
	pass
