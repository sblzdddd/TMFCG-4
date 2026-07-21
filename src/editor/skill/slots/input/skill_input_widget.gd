class_name SkillInputWidget
extends Resource

var label_text: String = ""

func get_linked_type() -> SkillNodeSlotConstants.PortType: return SkillNodeSlotConstants.PortType.UNDEFINED

func build_widget() -> Control:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SizeFlags.SIZE_SHRINK_BEGIN
	return label

func apply_to_control(_control: Control) -> void: return

func bind_control(_control: Control, _on_edit_begin: Callable = Callable()) -> void:
	return

func serialize() -> Dictionary: return {}

func deserialize(_data: Dictionary) -> void: return
