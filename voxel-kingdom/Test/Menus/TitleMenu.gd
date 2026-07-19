extends Node3D

@onready var title_buttons: Panel = %TitleButtons
@onready var title_screen: Control = %TitleScreen
@onready var press_any_key: Panel = %PressAnyKey
@onready var credits_back: Button = %CreditsBack
@onready var credits: Panel = %Credits
@onready var title: TextureRect = %Title

func _ready() -> void:
	Services.game_state.change_game_state(GameState.GameStates.MAIN_MENU)
	_connect_signals()
	_setup_initial_state()
	set_process_input(true)
	if OS.has_feature("web"):
		%Quit.visible = false

func _setup_initial_state() -> void:
	title_buttons.visible = false
	title_buttons.modulate.a = 0.0
	press_any_key.visible = true
	press_any_key.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_start_title_transition()
		set_process_input(false)


func _start_title_transition() -> void:
	var tween := create_tween()
	tween.tween_property(press_any_key, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func():
		press_any_key.visible = false
		title_buttons.visible = true
	)
	tween.tween_property(title_buttons, "modulate:a", 1.0, 0.6)


func _connect_signals() -> void:
	credits_back.button_up.connect(_credits_back)
	for button in title_buttons.get_children():
		if button is TextureButton: 
			button.button_down.connect(_on_button_down.bind(button))
			button.button_up.connect(_on_button_up.bind(button))
			button.mouse_entered.connect(_on_button_hover.bind(button, true))
			button.mouse_exited.connect(_on_button_hover.bind(button, false))


func _on_button_down(button: TextureButton) -> void:
	button.modulate = Color(0.522, 0.522, 0.522)


func _on_button_up(button: TextureButton) -> void:
	button.modulate = Color(1.0, 1.0, 1.0)
	_find_button(button)


func _find_button(button: TextureButton) -> void:
	match button.name:
		&"GenerateWorld":
			_new_game()
		&"Options":
			title_screen.visible = false
			Services.ui.show_ui(UI.Uis.GAME_SETTINGS)
		&"Credits":
				title.visible = false
				title_buttons.visible = false
				credits.visible = true
		&"Quit":
			Services.scene_loader.quit()


func _on_button_hover(button: TextureButton, mouse_entered: bool) -> void:
	var scale_direction = 1 if mouse_entered else -1
	button.scale += Vector2(.25, .25) * scale_direction


func _credits_back() -> void:
	credits.visible = false
	title.visible = true
	title_buttons.visible = true


func _new_game() -> void:
	Services.game_state.change_game_state(GameState.GameStates.PLAYING)
	Services.scene_loader.load_scene(SceneLoader.Scenes.TEST)


func _on_ui_hidden(ui:UI.Uis) -> void:
	match ui:
		UI.Uis.GAME_SETTINGS:
			title_screen.visible = true


func _disconnect_external_signals() -> void:
	pass
	#Services.ui.ui_hidden.disconnect(_on_ui_hidden) 


func _exit_tree() -> void:
	_disconnect_external_signals()
