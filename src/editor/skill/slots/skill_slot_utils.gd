class_name SkillSlotUtils
extends RefCounted

static func make_label(text: String, horizontal_size_flags: Control.SizeFlags) -> Label:
	var label := Label.new()
	label.custom_minimum_size.y = SkillConstants.ROW_MIN_HEIGHT
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = horizontal_size_flags
	return label


