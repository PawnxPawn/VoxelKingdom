class_name Player extends Entity

signal add_block(position:Vector3i, normal:Vector3i, terrian:TerrianData.TerrianType)
signal remove_block(position)

@export var chunk_manager:ChunkManager

@onready var _handler: ComponentHandler = %ComponentHandler
@onready var _sm: StateMachine = %StateMachine
@onready var ray_cast: RayCast3D = $RayCast3D

var is_fly_active:bool = false

var camera: CameraComponent = null
var input: InputSource = null
var gravity: GravityComponent = null
var look: LookComponent = null

var spawn_x = 10
var spawn_z = 10


func _ready() -> void:
	_connect_components()
	_setup_sm()
	
	chunk_manager.first_chunk_ready.connect(_spawn)

func _connect_components() -> void:
	input = _handler.get_component(InputSource)
	if input:
		_handler.set_active(InputSource, true)
		input.add_block_pressed.connect(_on_add_block)
		input.remove_block_pressed.connect(_on_remove_block)
	
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
	ray_cast.reparent(camera.camera)
	ray_cast.position = Vector3.ZERO
	var head_location = Vector3(0.0, 1.8, 0.0)
	camera.set_position(head_location)


func _physics_process(_delta: float) -> void:
	camera.set_rotation(look.pitch, look.yaw, 0)


func _spawn() -> void:
	await get_tree().create_timer(1.5).timeout
	var y:int =  chunk_manager.get_spawn_height(spawn_x, spawn_z) + 2
	global_position = Vector3(spawn_x, y, spawn_z)


func _on_add_block() -> void:
	var ray_hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if ray_hit != null:
		add_block.emit(ray_hit.hit_position, ray_hit.hit_normal, TerrianData.TerrianType.GRASS)


func _on_remove_block() -> void:
	var ray_hit: BlockRayCast.RayHit = ray_cast.get_ray_hit()
	if ray_hit != null:
		remove_block.emit(ray_hit.hit_position, ray_hit.hit_normal)
