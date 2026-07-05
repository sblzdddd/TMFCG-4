@tool
class_name SetNextRoundFirstNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/lightning.svg")
	node_category = SkillNodeCategory.Category.MODIFIER
	node_name = "设置下局先手"
	input_slot_specs = [
		SkillInputSpec.create(PortType.EVENT, "事件"),
		SkillInputSpec.create(PortType.CARD_HOLDER, "目标"),
		SkillInputSpec.from_widget("无视被动", SkillInputBool.create(false)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(PortType.EVENT, "事件"),
	]
