class_name CameraComponent extends Component
signal camera_entered
var camera: Camera3D

const MIN_FOV: float = 60.0
const MAX_FOV: float = 120.0

func ready() -> void:
	camera = Camera3D.new()
	camera.name = &"CameraComponent"
	_owner.add_child.call_deferred(camera)


func get_camera_path() -> NodePath:
	return camera.get_path()


func set_fov(fov: float) -> void:
	camera.fov = clamp(fov, MIN_FOV, MAX_FOV)


func set_position(position: Vector3) -> void:
	camera.position = position


func set_rotation(pitch:float, yaw:float, roll:float) -> void:
	camera.rotation = Vector3(pitch, 0, roll)
	_owner.rotation.y = yaw


func make_current() -> void:
	if camera.current: return
	camera.make_current()


func exit() -> void:
	pass
