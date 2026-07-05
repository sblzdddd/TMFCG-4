@tool
class_name DiscardCardNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/move_card.svg")
	node_category = SkillNodeCategory.Category.CARD
	node_name = "丢弃卡牌"
	input_slot_specs = [
		SkillInputSpec.create(PortType.EVENT, "事件"),
		SkillInputSpec.create(SkillConstants.array_type(PortType.CARD), "卡牌"),
	]
	output_slot_specs = [
		SkillSlotSpec.create(PortType.EVENT, "事件"),
	]
