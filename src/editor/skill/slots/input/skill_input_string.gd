@tool
class_name SkillInputString
extends SkillInputWidget

func get_linked_type() -> SkillConstants.PortType: return SkillConstants.PortType.STRING

@export var placeholder: String = ""
@export var value: String = ""

func build_widget(label_text: String = "") -> Control:
	var line_edit := LineEdit.new()
	line_edit.custom_minimum_size.y = SkillConstants.ROW_MIN_HEIGHT
	line_edit.placeholder_text = placeholder
	line_edit.text = value
	return line_edit
