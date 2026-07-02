class_name LookComponent extends Component

signal pitch_changed(pitch: float)
signal yaw_changed(yaw: float)

const PITCH_CLAMP_TOP: float = deg_to_rad(89.0)
const PITCH_CLAMP_BOTTOM: float = deg_to_rad(-89.0)
var pitch: float = 0.0
var yaw: float = 0.0

func _on_look(direction: Vector2) -> void:
	pitch = clamp(pitch - direction.y, PITCH_CLAMP_BOTTOM, PITCH_CLAMP_TOP)
	yaw -= direction.x
	
	yaw_changed.emit(yaw)
	pitch_changed.emit(pitch)
