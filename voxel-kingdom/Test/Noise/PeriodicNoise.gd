class_name PeriodicNoise
extends RefCounted

var world_size_x: float
var world_size_z: float
var _harmonics: Array[Dictionary] = []

func _init(size_x: float, size_z: float, octave_count: int, seed_value: int, terms_per_octave: int = 3) -> void:
	world_size_x = size_x
	world_size_z = size_z
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	for octave: int in range(octave_count):
		var base_freq: int = octave + 1
		for _term: int in range(terms_per_octave):
			var freq_x: int = rng.randi_range(-base_freq, base_freq)
			var freq_z: int = rng.randi_range(-base_freq, base_freq)
			if freq_x == 0 and freq_z == 0:
				freq_x = 1
			_harmonics.append({
				"freq_x": freq_x,
				"freq_z": freq_z,
				"phase": rng.randf_range(0.0, TAU),
				"amplitude": 1.0 / float(base_freq),
			})


func sample(world_x: float, world_z: float) -> float:
	var total: float = 0.0
	var max_amplitude: float = 0.0
	for harmonic: Dictionary in _harmonics:
		var angle: float = TAU * (
			harmonic["freq_x"] * world_x / world_size_x +
			harmonic["freq_z"] * world_z / world_size_z
		) + harmonic["phase"]
		total += sin(angle) * harmonic["amplitude"]
		max_amplitude += harmonic["amplitude"]
		
	if max_amplitude == 0.0:
		return 0.0
	return total / max_amplitude  # normalized to roughly [-1, 1]
