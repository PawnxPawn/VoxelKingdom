#-###########################################
# UI Manager
#-###########################################

class_name UI
extends Node

signal ui_shown(ui: Uis)
signal ui_hidden(ui: Uis)
signal all_uis_hidden

enum Uis {
	GAME_SETTINGS,
	PAUSE,
	HUD,
	GAME_OVER,
}

const _UI_SCENES_PRELOAD: Dictionary = {
	# Uis.GAME_SETTINGS: preload("uid://dxyeviydep8bt")
}

var ui_manager: CanvasLayer = null
var _active_uis: Dictionary = {}
var _loaded_uis: Dictionary = {}


#----------------
# Show UI
#----------------
func show_ui(ui: Uis) -> void:
	if not _ui_manager_check() or _active_uis.has(ui):
		return
	
	if not _UI_SCENES_PRELOAD.has(ui):
		push_error("UI: %s ui not found in _UI_SCENES_PRELOAD" % Uis.keys()[ui])
		return
	
	_load_ui_scene(ui)
	
	_active_uis[ui] = _loaded_uis[ui]
	_active_uis[ui].visible = true
	
	ui_shown.emit(ui)


#----------------
# Hide UI
#----------------
func hide_ui(ui: Uis) -> void:
	if not _ui_manager_check():
		return
	
	if not _active_uis.has(ui):
		push_warning("UI: %s not found in _active_uis." % Uis.keys()[ui])
		return
	
	_active_uis[ui].visible = false
	_active_uis.erase(ui)
	
	ui_hidden.emit(ui)


#----------------
# Hide All UIs
#----------------
func hide_all_uis() -> void:
	if not _ui_manager_check() or _active_uis.is_empty():
		return
	
	for ui in _active_uis:
		_active_uis[ui].visible = false
		ui_hidden.emit(ui)
	
	all_uis_hidden.emit()


#----------------
# Load UI Scene
#----------------
func _load_ui_scene(ui: Uis) -> void:
	if _loaded_uis.has(ui):
		return
	
	var instance: Node = _UI_SCENES_PRELOAD[ui].instantiate()
	ui_manager.add_child(instance)
	_loaded_uis[ui] = instance


#----------------
# UI Manager Check
#----------------
func _ui_manager_check() -> bool:
	if not ui_manager:
		push_error("UI: ui_manager is not set.")
		return false
	
	return true
