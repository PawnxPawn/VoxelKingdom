#-###########################################
# Water Overlay
#-###########################################
class_name WaterOverlay
extends ColorRect

enum FluidKind { WATER, LAVA }

@export var underwater_color: Color = Color(0.1, 0.35, 0.65, 0.35)
@export var lava_color: Color = Color(0.85, 0.25, 0.05, 0.55)
@export var fade_duration: float = 0.35

var _is_submerged: bool = false
var _current_kind: FluidKind = FluidKind.WATER
var _fade_tween: Tween

#----------------
# Ready
#----------------
func _ready() -> void:
	color = underwater_color
	color.a = 0.0

#----------------
# Submerged State
#----------------
func set_submerged(is_submerged: bool, fluid_kind: FluidKind = FluidKind.WATER) -> void:
	if is_submerged == _is_submerged and fluid_kind == _current_kind:
		return
		
	_is_submerged = is_submerged
	_current_kind = fluid_kind
	
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		
	var target_alpha: float
	
	if is_submerged:
		var base_color: Color = lava_color if fluid_kind == FluidKind.LAVA else underwater_color
		color = Color(base_color.r, base_color.g, base_color.b, color.a)
		target_alpha = base_color.a
	else:
		target_alpha = 0.0
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "color:a", target_alpha, fade_duration)
