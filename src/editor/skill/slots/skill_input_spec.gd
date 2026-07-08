@tool
class_name SkillInputSpec
extends SkillSlotSpec

@export var inline_widget: SkillInputWidget

static func create(
	Type: PortType = PortType.EVENT,
	LabelText: String = "",
	InlineWidget: SkillInputWidget = null
) -> SkillInputSpec:
	var spec := SkillInputSpec.new()
	spec.type = Type
	spec.label = LabelText
	spec.inline_widget = InlineWidget
	return spec

static func from_widget(label_text: String, InlineWidget: SkillInputWidget) -> SkillInputSpec:
	InlineWidget.label_text = label_text
	return create(InlineWidget.get_linked_type(), label_text, InlineWidget)

static func polymorphic_array(LabelText: String, Group: StringName = &"default") -> SkillInputSpec:
	var spec := create(SkillNodeSlotConstants.array_type(PortType.ANY), LabelText)
	spec.type_mode = TypeMode.POLYMORPHIC_ARRAY
	spec.polymorphic_group = Group
	return spec

func build_widget() -> Control:
	if type == PortType.UNDEFINED and inline_widget == null and label.is_empty():
		return SkillSlotUtils.make_row_filler()
	if inline_widget == null:
		return SkillSlotUtils.make_label(label, Control.SIZE_EXPAND_FILL)
	inline_widget.label_text = label
	return inline_widget.build_widget()

