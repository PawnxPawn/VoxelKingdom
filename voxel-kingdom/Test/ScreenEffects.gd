extends CanvasLayer

@onready var effect_rect: ColorRect = ColorRect.new()

var _lava_intensity: float = 0.0
var _lava_intensity_target: float = 0.0
var _in_lava: float = 0.0
var _in_lava_target: float = 0.0

var _cave_intensity: float = 0.0
var _cave_intensity_target: float = 0.0

const FADE_SPEED: float = 3.0

func _ready() -> void :
	layer = 50
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_rect.material = ShaderMaterial.new()
	effect_rect.material.shader = preload("uid://f7p67kqumc1y")
	add_child(effect_rect)


func _process(delta: float) -> void :
	_lava_intensity = move_toward(_lava_intensity, _lava_intensity_target, FADE_SPEED * delta)
	_in_lava = move_toward(_in_lava, _in_lava_target, FADE_SPEED * delta)
	_cave_intensity = move_toward(_cave_intensity, _cave_intensity_target, FADE_SPEED * delta)

	var mat: ShaderMaterial = effect_rect.material
	mat.set_shader_parameter("heat_haze_intensity", _lava_intensity)
	mat.set_shader_parameter("in_lava", _in_lava)
	mat.set_shader_parameter("cave_intensity", _cave_intensity)


func set_lava_proximity(falloff: float) -> void :
	_lava_intensity_target = clampf(falloff, 0.0, 1.0)


func set_in_lava(is_in: bool) -> void :
	_in_lava_target = 1.0 if is_in else 0.0


func set_cave_intensity(is_in_cave: bool) -> void :
	_cave_intensity_target = 1.0 if is_in_cave else 0.0


func trigger_droplets() -> void :
	var mat: ShaderMaterial = effect_rect.material
	mat.set_shader_parameter("droplet_start_time", Time.get_ticks_msec() / 1000.0)
