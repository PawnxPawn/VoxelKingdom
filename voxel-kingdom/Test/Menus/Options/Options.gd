extends Control

@onready var master_vol_slider: HSlider = %MasterVolSlider
@onready var master_vol_per: Label = %MasterVolPer

@onready var music_vol_slider: HSlider = %MusicVolSlider
@onready var music_vol_per: Label = %MusicVolPer

@onready var sfx_vol_slider: HSlider = %SFXVolSlider
@onready var sfx_vol_per: Label = %SFXVolPer

@onready var back: Button = %Back

@onready var song_label: Label = %SongLabel
@onready var swap_left: TextureButton = %SwapLeft
@onready var swap_right: TextureButton = %SwapRight


func _ready() -> void :
	_connect_signals()
	_load_initial_values()


func _connect_signals() -> void :
	master_vol_slider.value_changed.connect(_on_slider_changed.bind("Master"))
	music_vol_slider.value_changed.connect(_on_slider_changed.bind("Music"))
	sfx_vol_slider.value_changed.connect(_on_slider_changed.bind("SFX"))

	swap_left.button_up.connect(_on_swap_song.bind(-1))
	swap_left.mouse_entered.connect(_on_button_hover.bind(swap_left, true))
	swap_left.mouse_exited.connect(_on_button_hover.bind(swap_left, false))
	
	swap_right.button_up.connect(_on_swap_song.bind(1))
	swap_right.mouse_entered.connect(_on_button_hover.bind(swap_right, true))
	swap_right.mouse_exited.connect(_on_button_hover.bind(swap_right, false))

	back.button_up.connect(_on_back_pressed)
	
	Services.audio.song_changed.connect(_on_song_changed)

func _load_initial_values() -> void :

	master_vol_slider.value = Services.audio.get_master_volume()
	music_vol_slider.value = Services.audio.get_music_volume()
	sfx_vol_slider.value = Services.audio.get_sfx_volume()

	_update_label(master_vol_per, master_vol_slider.value)
	_update_label(music_vol_per, music_vol_slider.value)
	_update_label(sfx_vol_per, sfx_vol_slider.value)
	_update_song_label()

func _on_slider_changed(value: float, bus_name: String) -> void :
	Services.audio.play_sfx(Audio.SFX_Titles.MENU_CLICK)
	match bus_name:
		"Master":
			Services.audio.set_master_volume(value)
			_update_label(master_vol_per, value)
		"Music":
			Services.audio.set_music_volume(value)
			_update_label(music_vol_per, value)
		"SFX":
			Services.audio.set_sfx_volume(value)
			_update_label(sfx_vol_per, value)


func _update_label(label: Label, value: float) -> void :
	label.text = "%d%%" % value

func _update_song_label() -> void :
	song_label.text = Services.audio.get_current_song_name()


func _on_swap_song(direction: int) -> void :
	Services.audio.set_loop(false)
	Services.audio.set_random_play(true)
	Services.audio.play_sfx(Audio.SFX_Titles.MENU_CLICK)
	if direction > 0:
		Services.audio.next_song()
	else:
		Services.audio.previous_song()


func _on_song_changed(_song: Audio.Music_Titles) -> void :
	_update_song_label()


func _on_button_hover(button: TextureButton, mouse_enter: bool) -> void :
	Services.audio.play_sfx(Audio.SFX_Titles.MENU_CLICK)
	var scale_direction = 1 if mouse_enter else -1
	button.scale += Vector2(0.25, 0.25) * scale_direction


func _on_back_pressed() -> void :
	Services.audio.play_sfx(Audio.SFX_Titles.MENU_CLICK)
	Services.audio.save_settings()
	Services.ui.hide_ui(UI.Uis.GAME_SETTINGS)
