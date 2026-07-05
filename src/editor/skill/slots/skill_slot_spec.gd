@tool
class_name SkillSlotSpec
extends Resource

const PortType := SkillConstants.PortType

@export var type: PortType = PortType.EVENT
@export var label: String = ""
@export var enable_port: bool = true

static func create(Type: PortType = PortType.EVENT, LabelText: String = "") -> SkillSlotSpec:
	var spec := SkillSlotSpec.new()
	spec.type = Type
	spec.label = LabelText
	return spec

static func spacer() -> SkillSlotSpec:
	var spec := SkillSlotSpec.new()
	spec.enable_port = false
	return spec

func build_widget() -> Control:
	return SkillSlotUtils.make_label(label, Control.SIZE_SHRINK_END)
