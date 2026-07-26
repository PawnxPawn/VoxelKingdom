



class_name CameraComponent extends Component

signal camera_entered

var camera: Camera3D

const MIN_FOV: float = 60.0
const MAX_FOV: float = 120.0


var fov: float = 90.0





func ready() -> void :
	camera = Camera3D.new()
	camera.name = &"CameraComponent"
	_owner.add_child.call_deferred(camera)
	camera.fov = fov





func get_camera_path() -> NodePath:
	return camera.get_path()





func set_fov(new_fov: float) -> void :
	camera.fov = clamp(new_fov, MIN_FOV, MAX_FOV)





func set_position(new_position: Vector3) -> void :
	camera.position = new_position





func set_camera_cull_layers(layers: Dictionary) -> void :
	for layer_index in layers.keys():
		var layer_enabled: bool = layers[layer_index]
		camera.set_cull_mask_value(layer_index, layer_enabled)





func set_rotation(pitch: float, yaw: float, roll: float) -> void :
	camera.rotation = Vector3(pitch, 0.0, roll)
	_owner.rotation.y = yaw





func make_current() -> void :
	if camera.current:
		return

	camera.make_current()





func exit() -> void :
	pass
