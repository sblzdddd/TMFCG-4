@tool
class_name PlayCardNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/move_card.svg")
	node_category = SkillNodeCategory.Category.CARD
	node_name = "打出卡牌"
	input_slot_specs = [
		SkillInputSpec.create(PortType.EVENT, "事件"),
		SkillInputSpec.create(SkillConstants.array_type(PortType.CARD), "卡牌"),
		SkillInputSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "出牌目标"),
		SkillInputSpec.from_widget("分配张数", SkillInputNumber.create(1.0, 5.0, 1.0, 1.0, true)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(PortType.EVENT, "事件"),
	]
