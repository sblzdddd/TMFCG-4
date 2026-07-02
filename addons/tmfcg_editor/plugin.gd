@tool
extends EditorPlugin

const EDITOR_SCENE := preload("uid://cruf4r2hiqeyi")
const PLUGIN_ICON_PATH := "res://assets/textures/icons/CanvasTexture.svg"

var _editor_panel: Control


func _enter_tree() -> void:
	_editor_panel = EDITOR_SCENE.instantiate()
	EditorInterface.get_editor_main_screen().add_child(_editor_panel)
	_make_visible(false) # Hide the editor panel by default


func _exit_tree() -> void:
	if _editor_panel:
		_editor_panel.queue_free()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Cards"


func _get_plugin_icon() -> Texture2D:
	return load(PLUGIN_ICON_PATH)


func _make_visible(visible: bool) -> void:
	if _editor_panel:
		_editor_panel.visible = visible
