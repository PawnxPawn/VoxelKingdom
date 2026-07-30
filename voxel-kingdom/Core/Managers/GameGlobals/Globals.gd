class_name Globals
extends RefCounted

var world_seed: int = 0

func set_world_seed_from_text(text: String) -> void:
	text = text.strip_edges()
	
	if text.is_empty():
		world_seed = randi()
	elif text.is_valid_int():
		world_seed = text.to_int()
	else:
		world_seed = text.hash()
