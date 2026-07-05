@tool
class_name SkillInputWidget
extends Resource

var label_text: String = ""

func get_linked_type() -> SkillConstants.PortType: return SkillConstants.PortType.UNDEFINED

func build_widget() -> Control:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.y = SkillConstants.ROW_MIN_HEIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SizeFlags.SIZE_SHRINK_BEGIN
	return label
