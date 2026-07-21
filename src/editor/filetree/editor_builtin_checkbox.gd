extends CheckBox
class_name EditorBuiltinCheckbox


func _ready() -> void:
	visible = Engine.is_editor_hint()
