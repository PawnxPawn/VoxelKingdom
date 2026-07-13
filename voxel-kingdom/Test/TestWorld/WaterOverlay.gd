#-###########################################
# WaterOverlay
#-###########################################

class_name WaterOverlay
extends ColorRect

@export var underwater_color: Color = Color(0.1, 0.35, 0.65, 0.35)
@export var fade_duration: float = 0.35

var _is_submerged: bool = false
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
func set_submerged(is_submerged: bool) -> void:
	if is_submerged == _is_submerged:
		return
		
	_is_submerged = is_submerged
	
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		
	var target_alpha: float = underwater_color.a if is_submerged else 0.0
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "color:a", target_alpha, fade_duration)
