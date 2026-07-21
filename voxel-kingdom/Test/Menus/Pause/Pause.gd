extends Control

@onready var pause_buttons: Panel = %PauseButtons
@onready var credits_back: Button = %CreditsBack
@onready var credits: Panel = %Credits
@onready var pause_screen: Panel = $PauseScreen

func _ready() -> void:
	_connect_signals()
	set_process_input(true)
	if OS.has_feature("web"):
		%Quit.visible = false


func _connect_signals() -> void:
	Services.ui.ui_hidden.connect(_on_ui_hidden)
	credits_back.button_up.connect(_credits_back)
	for button in pause_buttons.get_children():
		if button is TextureButton: 
			button.button_down.connect(_on_button_down.bind(button))
			button.button_up.connect(_on_button_up.bind(button))
			button.mouse_entered.connect(_on_button_hover.bind(button, true))
			button.mouse_exited.connect(_on_button_hover.bind(button, false))


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(&"Pause") and self.visible:
		if pause_screen.visible:
			_unpause()


func _on_button_down(button: TextureButton) -> void:
	button.modulate = Color(0.522, 0.522, 0.522)


func _on_button_up(button: TextureButton) -> void:
	button.modulate = Color(1.0, 1.0, 1.0)
	_find_button(button)


func _find_button(button: TextureButton) -> void:
	match button.name:
		&"Resume":
			_unpause()
		&"Options":
			pause_screen.visible = false
			pause_screen.mouse_filter = Control.MOUSE_FILTER_PASS
			Services.ui.show_ui(UI.Uis.GAME_SETTINGS)
		&"Credits":
			pause_screen.visible = false
			credits.visible = true
		&"Quit":
			Services.scene_loader.quit()


func _on_button_hover(button: TextureButton, mouse_enter: bool) -> void:
	var scale_direction = 1 if mouse_enter else -1
	button.scale += Vector2(.25, .25) * scale_direction


func _credits_back() -> void:
	credits.visible = false
	pause_screen.mouse_filter =Control.MOUSE_FILTER_IGNORE
	pause_screen.visible = true



func _unpause() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Services.ui.hide_ui(UI.Uis.PAUSE)
	get_tree().paused = false


func _on_ui_hidden(ui:UI.Uis) -> void:
	match ui:
		UI.Uis.GAME_SETTINGS:
			pause_screen.visible = true


func _disconnect_external_signals() -> void:
	Services.ui.ui_hidden.disconnect(_on_ui_hidden)

func _exit_tree() -> void:
	_disconnect_external_signals()
