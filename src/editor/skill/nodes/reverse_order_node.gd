@tool
class_name ReverseOrderNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/reverse.svg")
	node_category = SkillNodeCategory.Category.MODIFIER
	node_name = "反转全局顺序"
	input_slot_specs = [
		SkillInputSpec.create(PortType.EVENT, "事件"),
		SkillInputSpec.from_widget("无视被动", SkillInputBool.create(false)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(PortType.EVENT, "事件"),
	]
