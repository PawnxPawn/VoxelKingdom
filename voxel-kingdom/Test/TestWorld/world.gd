extends Node3D
@export var world_size: Vector3 = Vector3(16, 16, 16)
@export_range(-1, 1) var cut_off: float = 0.01
@export var noise_scale: float = 0.08

var _cube_scene: PackedScene = preload("uid://c6yyee7na55t2")

var cubes: int = 0

func _ready() -> void:
	#var start_time = Time.get_ticks_usec()
	#var chunk := VoxelChunk.new()
	#add_child(chunk)
	#var end_time = Time.get_ticks_usec()
	#var gen_time = (end_time - start_time) / 1000000.0
	#print("Gen Time: %s" % gen_time)
	Performance.add_custom_monitor(&"Game/Cubes", func(): return cubes)
	print(world_size.x * world_size.y	 * world_size.z)
	var rng := FastNoiseLite.new()
	rng.frequency = noise_scale
	
	var start_time = Time.get_ticks_usec()
	
	for x in range(world_size.x):
		for z in range(world_size.z):
			for y in range(world_size.y):
				var ran := rng.get_noise_3d(x, y, z)
				if ran > cut_off:
					var new_cube: CSGBox3D = _cube_scene.instantiate()
					new_cube.position = Vector3(x, y, z)
					add_child(new_cube)
					new_cube.use_collision = true
					cubes += 1
	
	var end_time = Time.get_ticks_usec()
	var gen_time = (end_time - start_time) / 1000000.0
	
	print("Blocks in world: %s\nGen Time: %s" % [cubes, gen_time])
