#-#################################
# Audio Services
#-#################################
class_name Audio
extends Node

enum Music_Titles {
	MENUS, C4188, VoxelKingdom, C4189
}

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

var music: Dictionary = {
	Music_Titles.MENUS: preload("uid://cmdld0usdketi"),
	Music_Titles.C4188: preload("uid://ucajyunnv11n"),
	Music_Titles.VoxelKingdom: preload("uid://lblty5d1hbi5"),
	Music_Titles.C4189: preload("uid://bf6hdj40jwk5a")
}


var master_bus:int = AudioServer.get_bus_index("Master")
var music_bus:int = AudioServer.get_bus_index("Music")
var sfx_bus:int = AudioServer.get_bus_index("SFX")

var audio_manager: Node = null:
	set(value):
		audio_manager = value
		_add_music_player()

var _last_random_key: Music_Titles = 0 as Music_Titles

var _loop: bool = false
var _random_play: bool = false

#-##############################
# Ready
#-##############################

func _ready() -> void:
	_load_settings()


func _add_music_player() -> void:
	music_player.bus = &"Music"
	
	var playlist: AudioStreamPlaylist = AudioStreamPlaylist.new()
	playlist.stream_count = music.size()
	
	var i: int = 0
	for song: AudioStream in music.values():
		playlist.set_list_stream(i, song)
		i += 1
	
	playlist.shuffle = false
	playlist.loop = false
	
	music_player.stream = playlist
	music_player.finished.connect(_play_next_song)
	audio_manager.add_child(music_player)

#-##############################
# Volume Control
#-##############################

func set_master_volume(percent: float) -> void:
	AudioServer.set_bus_volume_db(master_bus, _percent_to_db(percent))


func set_music_volume(percent: float) -> void:
	AudioServer.set_bus_volume_db(music_bus, _percent_to_db(percent))


func set_sfx_volume(percent: float) -> void:
	AudioServer.set_bus_volume_db(sfx_bus, _percent_to_db(percent))


func get_master_volume() -> float:
	return _db_to_percent(AudioServer.get_bus_volume_db(master_bus))


func get_music_volume() -> float:
	return _db_to_percent(AudioServer.get_bus_volume_db(music_bus))


func get_sfx_volume() -> float:
	return _db_to_percent(AudioServer.get_bus_volume_db(sfx_bus))


#-##############################
# Playback
#-##############################

func play_music(song: Music_Titles = Music_Titles.MENUS) -> void:
	if _random_play:
		play_random_song()
		return
	_switch_stream(music[song])


func play_random_song() -> void:
	var values: Array = Music_Titles.values()
	var song_key: Music_Titles
	
	if values.size() <= 1:
		song_key = values[0]
	else:
		while true:
			song_key = values[randi_range(0, values.size() - 1)]
			if song_key != _last_random_key:
				break
	
	_last_random_key = song_key
	_switch_stream(music[song_key])


func _switch_stream(stream: AudioStream) -> void:
	music_player.stop()
	music_player.stream = stream
	await get_tree().process_frame
	music_player.play()


func stop_music() -> void:
	music_player.stop()


func play_sfx(stream: AudioStream, player: AudioStreamPlayer) -> void:
	player.bus = "SFX"
	player.stream = stream
	player.play()


#-##############################
# Loop / Repeat
#-##############################

func set_loop(should_loop: bool) -> void:
	_loop = should_loop

func set_random_play(should_random: bool) -> void:
	_random_play = should_random

#-##############################
# Load/Save
#-##############################

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", get_master_volume())
	cfg.set_value("audio", "music", get_music_volume())
	cfg.set_value("audio", "sfx", get_sfx_volume())
	cfg.save("user://audio.cfg")

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://audio.cfg")
	if err != OK:
		return

	set_master_volume(cfg.get_value("audio", "master", 100))
	set_music_volume(cfg.get_value("audio", "music", 100))
	set_sfx_volume(cfg.get_value("audio", "sfx", 100))

#-########func _play_next_song() -> void: 
	#TODO:
	# Add a play next track (w/ loop)
	
	if _random_play:
		play_random_song()
		return
	if _loop:
		music_player.play()
		return######################
# Helpers
#-##############################

func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)

func _db_to_percent(db: float) -> float:
	return db_to_linear(db) * 100.0


#-################################
# Signals
#-################################

func _play_next_song() -> void:
	if _random_play:
		play_random_song()
		return
	if _loop:
		music_player.play()
		return
	
