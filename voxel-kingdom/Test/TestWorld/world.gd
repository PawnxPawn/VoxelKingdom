extends Node3D

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var cubes: int = 0
var data: Dictionary[Vector3, Color] = {}

func _ready() -> void:
	#Performance.add_custom_monitor(&"Game/Cubes", func(): return cubes)
	audio_stream_player.finished.connect(_start_next_track)
	pass


func _start_next_track() -> void:
	audio_stream_player.play()
