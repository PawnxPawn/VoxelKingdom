extends Control

@onready var master_vol_slider: HSlider = %MasterVolSlider
@onready var master_vol_per: Label = %MasterVolPer

@onready var music_vol_slider: HSlider = %MusicVolSlider
@onready var music_vol_per: Label = %MusicVolPer

@onready var sfx_vol_slider: HSlider = %SFXVolSlider
@onready var sfx_vol_per: Label = %SFXVolPer

@onready var back: Button = %Back


func _ready() -> void:
	_connect_signals()
	_load_initial_values()


func _connect_signals() -> void:
	master_vol_slider.value_changed.connect(_on_slider_changed.bind("Master"))
	music_vol_slider.value_changed.connect(_on_slider_changed.bind("Music"))
	sfx_vol_slider.value_changed.connect(_on_slider_changed.bind("SFX"))

	back.button_up.connect(_on_back_pressed)


func _load_initial_values() -> void:
	# Load from AudioService instead of AudioServer
	master_vol_slider.value = Services.audio.get_master_volume()
	music_vol_slider.value = Services.audio.get_music_volume()
	sfx_vol_slider.value = Services.audio.get_sfx_volume()
	
	_update_label(master_vol_per, master_vol_slider.value)
	_update_label(music_vol_per, music_vol_slider.value)
	_update_label(sfx_vol_per, sfx_vol_slider.value)


func _on_slider_changed(value: float, bus_name: String) -> void:
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


func _update_label(label: Label, value: float) -> void:
	label.text = "%d%%" % value


func _on_back_pressed() -> void:
	Services.audio.save_settings()
	Services.ui.hide_ui(UI.Uis.GAME_SETTINGS)
