@tool
extends Tree
class_name CharacterFileTree

const FileTreeLayout := preload("res://src/editor/filetree/file_tree_layout.gd")

signal resource_selected(metadata: Dictionary)

@export var folder_icon: Texture2D
@export var character_icon: Texture2D

var show_builtin := true
var _section_root: TreeItem = null


func _ready() -> void:
	FileTreeLayout.prepare(self)
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)
	if not item_collapsed.is_connected(_on_item_collapsed):
		item_collapsed.connect(_on_item_collapsed)
	refresh()


func refresh() -> void:
	clear()
	_section_root = create_item()
	_section_root.set_text(0, "角色")
	_section_root.set_selectable(0, false)
	if folder_icon:
		_section_root.set_icon(0, folder_icon)
	for path in CharacterDataStore.list_paths(show_builtin):
		_add_character_item(CharacterDataStore.load_character(path), path)
	call_deferred("_fit_content_height")


func get_selected_metadata() -> Dictionary:
	var item := get_selected()
	return {} if item == null else item.get_metadata(0)


func _add_character_item(character: DialogicCharacter, path: String) -> void:
	if character == null:
		return
	var label := character.display_name
	if label.is_empty():
		label = path.get_file().get_basename()
	var item := create_item(_section_root)
	item.set_text(0, label)
	item.set_metadata(0, {
		"type": "character",
		"path": path,
		"builtin": ResourceFsUtils.is_builtin_path(path),
	})
	item.set_icon(0, character_icon)


func _on_item_selected() -> void:
	var item := get_selected()
	resource_selected.emit({} if item == null else item.get_metadata(0))


func _on_item_collapsed(_item: TreeItem) -> void:
	call_deferred("_fit_content_height")


func _fit_content_height() -> void:
	FileTreeLayout.fit_height(self)
