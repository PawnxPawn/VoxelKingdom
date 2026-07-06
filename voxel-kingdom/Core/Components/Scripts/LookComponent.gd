class_name LookComponent extends Component

signal pitch_changed(pitch: float)
signal yaw_changed(yaw: float)

var pitch_clamp_top: float = deg_to_rad(89.0)
var pitch_clamp_bottom: float = deg_to_rad(-89.0)
var pitch: float = 0.0
var yaw: float = 0.0


func _on_look(direction: Vector2) -> void:
	pitch = clamp(pitch - direction.y, pitch_clamp_bottom, pitch_clamp_top)
	yaw -= direction.x
	
	yaw_changed.emit(yaw)
	pitch_changed.emit(pitch)
