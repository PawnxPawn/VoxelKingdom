class_name Player extends Entity

@onready var _handler: ComponentHandler = %ComponentHandler
@onready var _sm: StateMachine = %StateMachine

var is_fly_active:bool = false

var camera: CameraComponent = null
var input: InputSource = null
var gravity: GravityComponent = null
var look: LookComponent = null

func _ready() -> void:
	_connect_components()
	_setup_sm()

func _connect_components() -> void:
	input = _handler.get_component(InputSource)
	if input:
		_handler.set_active(InputSource, true)
	
	look = _handler.get_component(LookComponent)
	if look and input:
		input.look_direction_changed.connect(look._on_look)
	
	gravity = _handler.get_component(GravityComponent)
	if gravity:
		_handler.set_active(GravityComponent, true)
	
	_setup_camera()


func _setup_sm() -> void:
	_sm.init(_handler)


func _setup_camera() -> void:
	camera = _handler.get_component(CameraComponent)
	if not camera: return
	var head_location = Vector3(0.0, 1.4, 0.0)
	camera.set_position(head_location)


func _physics_process(_delta: float) -> void:
	camera.set_rotation(look.pitch, look.yaw, 0)
