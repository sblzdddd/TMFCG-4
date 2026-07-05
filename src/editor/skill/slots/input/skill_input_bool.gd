@tool
class_name SkillInputBool
extends SkillInputWidget

func get_linked_type() -> SkillConstants.PortType: return SkillConstants.PortType.BOOLEAN

@export var pressed: bool = false


static func create(Pressed: bool = false) -> SkillInputBool:
	var widget := SkillInputBool.new()
	widget.pressed = Pressed
	return widget


func build_widget() -> Control:
	var checkbox := CheckBox.new()
	checkbox.custom_minimum_size.y = SkillConstants.ROW_MIN_HEIGHT
	checkbox.text = label_text
	checkbox.button_pressed = pressed
	return checkbox