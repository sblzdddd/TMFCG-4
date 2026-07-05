@tool
class_name OffsetPlayerNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/order.svg")
	node_category = SkillNodeCategory.Category.CARD_HOLDER
	node_name = "按出牌顺序获取玩家"
	input_slot_specs = [
		SkillInputSpec.create(PortType.CARD_HOLDER, "当前玩家"),
		SkillInputSpec.from_widget("偏移数量", SkillInputNumber.create(-5.0, 5.0, 1.0, 1.0, true)),
		SkillInputSpec.from_widget("玩家数量", SkillInputNumber.create(0.0, 5.0, 1.0, 1.0, true)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "玩家"),
	]
