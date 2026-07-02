extends Tree
class_name EditorFileTree

@export var folder_icon: Texture2D
var _root: TreeItem = null
var _deck_root: TreeItem = null
var _character_list_root: TreeItem = null

func create_folder(folder_name: String, parent: TreeItem) -> TreeItem:
    var folder = create_item(parent)
    folder.set_icon(0, folder_icon)
    folder.set_text(0, folder_name)
    return folder


func _ready() -> void:
    _root = create_item()
    hide_root = true
    _deck_root = create_folder("牌组", _root)
    _character_list_root = create_folder("角色", _root)
