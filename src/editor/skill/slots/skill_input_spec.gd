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

static func spacer() -> SkillInputSpec:
	var spec := SkillInputSpec.new()
	spec.enable_port = false
	return spec

func build_widget() -> Control:
	if not enable_port and inline_widget == null and label.is_empty():
		return null
	if inline_widget == null:
		return SkillSlotUtils.make_label(label, Control.SIZE_EXPAND_FILL)
	inline_widget.label_text = label
	return inline_widget.build_widget()

