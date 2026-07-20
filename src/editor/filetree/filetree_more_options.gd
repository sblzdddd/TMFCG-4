@tool
extends MenuButton
class_name EditorMoreOptions

enum MenuId {
	SHOW_BUILTIN_DECKS,
}

@export var _files_panel: FilesPanelController


func _ready() -> void:
	var menu := get_popup()
	menu.hide_on_checkable_item_selection = false
	menu.id_pressed.connect(_on_menu_id_pressed)
	if _files_panel == null:
		return
	_files_panel.set_show_builtin_decks(menu.is_item_checked(MenuId.SHOW_BUILTIN_DECKS))


func _on_menu_id_pressed(id: int) -> void:
	var menu := get_popup()
	var index := menu.get_item_index(id)
	var checked := not menu.is_item_checked(index)
	if _files_panel:
		match id:
			MenuId.SHOW_BUILTIN_DECKS:
				_files_panel.set_show_builtin_decks(checked)
	menu.set_item_checked(index, checked)
