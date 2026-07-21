#-###########################################
# World
#-###########################################

extends Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Services.audio.set_random_play(true)
	Services.audio.play_music()
