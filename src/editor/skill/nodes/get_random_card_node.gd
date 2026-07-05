@tool
class_name GetRandomCardNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/random.svg")
	node_category = SkillNodeCategory.Category.CARD
	node_name = "随机获取卡牌"
	input_slot_specs = [
		SkillInputSpec.create(PortType.EVENT, "事件"),
		SkillInputSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "目标"),
		SkillInputSpec.from_widget("获取张数", SkillInputNumber.create(1.0, 10.0, 1.0, 1.0, true)),
		SkillInputSpec.from_widget("无视被动", SkillInputBool.create(false)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(PortType.EVENT, "事件"),
		SkillSlotSpec.create(SkillConstants.array_type(PortType.CARD), "卡牌"),
	]
