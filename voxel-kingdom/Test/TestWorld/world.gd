extends Node3D

@export var world_size: Vector3 = Vector3(16, 16, 16)
@export var colors: Array[Color]
@export_range(-1, 1) var cut_off: float = 0.01
@export var noise_scale: float = 0.08

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D



var _cube_scene: PackedScene = preload("uid://c6yyee7na55t2")

var cubes: int = 0
var data: Dictionary[Vector3, Color] = {}

func _ready() -> void:
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	Performance.add_custom_monitor(&"Game/Cubes", func(): return cubes)
	var start_time = Time.get_ticks_usec()
	
	#surface_tool_chunk_loader() # FAILED ATTEMPT
	chunk_gen_loop()
	mesh_instance.generate_mesh(data)
	
	var end_time = Time.get_ticks_usec()
	var gen_time = (end_time - start_time) / 1000000.0
	
	print("Blocks in world: %s\nGen Time: %s" % [cubes, gen_time])


#func surface_tool_chunk_loader() -> void:
	#var start_time = Time.get_ticks_usec()
	#var chunk := VoxelChunk.new()
	#add_child(chunk)
	#var end_time = Time.get_ticks_usec()
	#var gen_time = (end_time - start_time) / 1000000.0
	#print("Gen Time: %s" % gen_time)
#
func chunk_gen_loop() -> void:
	var rng := FastNoiseLite.new()
	rng.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#rng.frequency = noise_scale
	
	for x in range(world_size.x):
		for z in range(world_size.z):
			for y in range(world_size.y):
				var ran := rng.get_noise_3d(x, y, z)
				if ran > cut_off:
					data[Vector3(x, y, z)] = colors[y % colors.size()]
					#world_gen_by_cube(x, y, z)
					cubes += 1
	#multi_mesh_instance.multimesh.instance_count = data.size()
	#
	#for i in range(multi_mesh_instance.multimesh.instance_count):
		#multi_mesh_instance.multimesh.set_instance_transform(i, Transform3D(Basis(), data[i]))
		#multi_mesh_instance.multimesh.set_instance_color(i, colors[randf() * colors.size()])

func world_gen_by_cube(x: float, y: float, z: float) -> void:
	var new_cube: CSGBox3D = _cube_scene.instantiate()
	new_cube.position = Vector3(x, y, z)
	add_child(new_cube)
	new_cube.use_collision = true
