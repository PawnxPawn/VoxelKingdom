class_name ChunkManager extends Node

var instance: ChunkManager

@export var dimensions: Vector3i = Vector3i(128, 64, 128)
@export var colors: Array[Color]
@export var chunk_size: int = 32

@export var noise_frequency: float = 0.003
@export var noise_seed: int = 0


var noise = FastNoiseLite.new()

var number_of_chunks: Vector3i
var chunk_scene: PackedScene = preload("uid://vqyykbxy7a60")

var loading_threads: Array[Thread] = [
	Thread.new(),
	Thread.new(),
	Thread.new(),
	Thread.new(),
	]

var cubes: int = 0

var _start_time:float = 0.0
var _completed_threads: int = 0
var _completion_mutex := Mutex.new()

func _ready() -> void:
	instance = self
	
	_start_time = Time.get_ticks_usec()
	
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.seed = noise_seed
	
	number_of_chunks = Vector3i(
		ceili(float(dimensions.x) / chunk_size),
		ceili(float(dimensions.y) / chunk_size),
		ceili(float(dimensions.z) / chunk_size)
	)
	
	var half_x: int = ceili(number_of_chunks.x / 2.0)
	var half_z: int = ceili(number_of_chunks.z / 2.0)
	var remainder_x: int = number_of_chunks.x - half_x * 2
	var remainder_z: int = number_of_chunks.z - half_z * 2
	
	loading_threads[0].start(_run_generation.bind(Vector3i(0, 0, 0), Vector3i(half_x, number_of_chunks.y, half_z)))
	loading_threads[1].start(_run_generation.bind(Vector3i(half_x, 0, 0), Vector3i(half_x + remainder_x, number_of_chunks.y, half_z)))
	loading_threads[2].start(_run_generation.bind(Vector3i(0, 0, half_z), Vector3i(half_x, number_of_chunks.y, half_z + remainder_z)))
	loading_threads[3].start(_run_generation.bind(Vector3i(half_x, 0, half_z), Vector3i(half_x + remainder_x, number_of_chunks.y, half_z + remainder_z)))


func _run_generation(chunk_start: Vector3i, chunk_count: Vector3i) -> void:
	generate_chunks(chunk_start, chunk_count)
	_completion_mutex.lock()
	_completed_threads += 1
	var all_done: bool = _completed_threads == loading_threads.size()
	_completion_mutex.unlock()

	if all_done:
		var gen_time = (Time.get_ticks_usec() - _start_time) / 1000000.0
		print("Blocks in world: %d\nGen Time: %s" % [Chunk.cube_count, gen_time])


func generate_chunks(chunk_start: Vector3i, chunk_count: Vector3i) -> void:
	for x in range(chunk_start.x, chunk_count.x):
		for z in range(chunk_start.z, chunk_count.z):
			for y in range(chunk_count.y):
				var new_chunk: Chunk = chunk_scene.instantiate()
				new_chunk.position = Vector3(x, y, z) * chunk_size
				new_chunk.generate_date(chunk_size, dimensions.y, noise, colors)
				new_chunk.generate_mesh()
				add_child.call_deferred(new_chunk)
	print("Thread ID: %s finished" % OS.get_thread_caller_id())


func _exit_tree() -> void:
	for thread in loading_threads:
		thread.wait_to_finish()
