#-###########################################
# Component Base
#-###########################################

@abstract class_name Component extends RefCounted

signal activated
signal deactivated

var _owner: Node

# Activation flag with auto‑emit
var is_active: bool = false:
	set(value):
		is_active = value
		if is_active:
			activated.emit()
		else:
			deactivated.emit()


func _init(p_owner: Node) -> void:
	_owner = p_owner
	activated.connect(_on_activated)
	deactivated.connect(_on_deactivated)

# Optional setup stage
func setup() -> void:
	pass


func ready() -> void:
	pass


func process(_delta: float) -> void:
	pass


func physics_process(_delta: float) -> void:
	pass

# Only used if interacting with physics bodies
func integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	pass


func input(_event: InputEvent) -> void:
	pass


func unhandled_input(_event: InputEvent) -> void:
	pass


func paused() -> void:
	pass


func unpaused() -> void:
	pass


func exit() -> void:
	pass

# Activation callback
func _on_activated() -> void:
	pass

# Deactivation callback
func _on_deactivated() -> void:
	pass
