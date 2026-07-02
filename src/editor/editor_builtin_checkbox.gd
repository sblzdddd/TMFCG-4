@tool
extends CheckBox
class_name EditorBuiltinCheckbox


func _ready() -> void:
	visible = OS.has_feature("editor")
