@tool
class_name FreezeNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/freeze.svg")
	node_category = SkillNodeCategory.Category.MODIFIER
	node_name = "冻结目标"
	input_slot_specs = [
		SkillInputSpec.create(PortType.EVENT, "事件"),
		SkillInputSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "目标"),
		SkillInputSpec.from_widget("冻结轮数", SkillInputNumber.create(1.0, 10.0, 1.0, 1.0, true)),
		SkillInputSpec.from_widget("无法主动出牌", SkillInputBool.create(false)),
		SkillInputSpec.from_widget("无法被动出牌", SkillInputBool.create(false)),
		SkillInputSpec.from_widget("无法无视场合出牌", SkillInputBool.create(false)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(PortType.EVENT, "事件"),
	]
