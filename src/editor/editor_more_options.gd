@tool
extends MenuButton
class_name EditorMoreOptions

enum MenuId {
	SHOW_BUILTIN_DECKS,
	SHOW_BUILTIN_CHARACTERS
}

@export var _file_tree: EditorFileTree


func _ready() -> void:
	var menu := get_popup()
	menu.hide_on_checkable_item_selection = false
	menu.id_pressed.connect(_on_menu_id_pressed)
	_file_tree.show_builtin_characters = menu.is_item_checked(MenuId.SHOW_BUILTIN_CHARACTERS)
	_file_tree.show_builtin_decks = menu.is_item_checked(MenuId.SHOW_BUILTIN_DECKS)
	_file_tree.refresh()


func _on_menu_id_pressed(id: int) -> void:
	var menu := get_popup()
	var index := menu.get_item_index(id)
	# id_pressed fires before PopupMenu updates check item state.
	var checked := not menu.is_item_checked(index)
	match id:
		MenuId.SHOW_BUILTIN_CHARACTERS:
			_file_tree.show_builtin_characters = checked
		MenuId.SHOW_BUILTIN_DECKS:
			_file_tree.show_builtin_decks = checked
	_file_tree.refresh()
	menu.set_item_checked(index, checked)
