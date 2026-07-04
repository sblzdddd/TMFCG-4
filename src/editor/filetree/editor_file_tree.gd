@tool
extends Tree
class_name EditorFileTree


@export var folder_icon: Texture2D
@export var deck_icon: Texture2D
@export var character_icon: Texture2D
var _root: TreeItem = null
var _deck_root: TreeItem = null
var _character_list_root: TreeItem = null
var show_builtin_characters := true
var show_builtin_decks := true


func create_folder(folder_name: String, parent: TreeItem) -> TreeItem:
	var folder = create_item(parent)
	folder.set_icon(0, folder_icon)
	folder.set_text(0, folder_name)
	return folder


func _ready() -> void:
	ResourceFsUtils.ensure_directories()
	_root = create_item()
	hide_root = true
	_deck_root = create_folder("牌组", _root)
	_character_list_root = create_folder("角色", _root)
	refresh()


func refresh() -> void:
	_clear_children(_deck_root)
	_clear_children(_character_list_root)
	hide_root = true

	if show_builtin_decks:
		for path in ResourceFsUtils.list_files(ResConst.PRESET_DECKS_DIR, "tres"):
			add_deck_item(load(path) as DeckData, path)
	for path in ResourceFsUtils.list_files(ResConst.USER_DECKS_DIR, "tres"):
		add_deck_item(load(path) as DeckData, path)

	if show_builtin_characters:
		for path in ResourceFsUtils.list_files(ResConst.PRESET_CHARACTERS_DIR, "dch"):
			add_character_item(load(path) as DialogicCharacter, path)
	for path in ResourceFsUtils.list_files(ResConst.USER_CHARACTERS_DIR, "dch"):
		add_character_item(load(path) as DialogicCharacter, path)


func add_deck_item(deck: DeckData, path: String) -> TreeItem:
	if deck == null:
		return null
	if path.begins_with(ResConst.PRESET_DECKS_DIR) and not show_builtin_decks:
		return null

	var item := create_item(_deck_root)
	item.set_text(0, deck.name if not deck.name.is_empty() else path.get_file().get_basename())
	item.set_metadata(0, {"type": "deck", "path": path})
	item.set_icon(0, deck_icon)
	return item


func add_character_item(character: DialogicCharacter, path: String) -> TreeItem:
	if character == null:
		return null
	if path.begins_with(ResConst.PRESET_CHARACTERS_DIR) and not show_builtin_characters:
		return null

	var label := character.display_name
	if label.is_empty():
		label = path.get_file().get_basename()

	var item := create_item(_character_list_root)
	item.set_text(0, label)
	item.set_metadata(0, {"type": "character", "path": path})
	item.set_icon(0, character_icon)
	return item


func _clear_children(folder: TreeItem) -> void:
	if folder == null:
		return
	var child := folder.get_first_child()
	while child:
		var next := child.get_next()
		child.free()
		child = next
