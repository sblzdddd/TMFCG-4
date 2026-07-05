class_name SkillSlotSpec
extends Resource

const PortType := SkillConstants.PortType

@export var type: PortType = PortType.EVENT
@export var label: String = ""


static func create(type: PortType = PortType.EVENT, label_text: String = "") -> SkillSlotSpec:
	var spec := SkillSlotSpec.new()
	spec.type = type
	spec.label = label_text
	return spec

func build_widget() -> Control:
	return SkillSlotUtils.make_label()
