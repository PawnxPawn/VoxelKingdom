#-###########################################
# World
#-###########################################

extends Node3D

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var cubes: int = 0
var data: Dictionary[Vector3, Color] = {}


#----------------
# Ready
#----------------
func _ready() -> void:
	audio_stream_player.finished.connect(_start_next_track)


#----------------
# Next Track
#----------------
func _start_next_track() -> void:
	audio_stream_player.play()
