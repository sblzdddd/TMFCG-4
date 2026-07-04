@tool
extends CheckBox
class_name EditorBuiltinCheckbox


func _ready() -> void:
	visible = get_tree().edited_scene_root != null && get_tree().edited_scene_root in [self, owner]
