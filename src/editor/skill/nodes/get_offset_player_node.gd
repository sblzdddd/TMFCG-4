@tool
class_name GetOffsetPlayerNode extends BaseSkillNode

const PortType := SkillNodeSlotConstants.PortType

func info() -> void:
	node_category = SkillNodeCategoryConstants.Category.CARD_HOLDER
	node_name = "按出牌顺序获取玩家"
	input_slot_specs = [
		SkillInputSpec.create(PortType.CARD_HOLDER, "当前玩家"),
		SkillInputSpec.from_widget("偏移数量", SkillInputNumber.create(-5.0, 5.0, 1.0, 1.0, true)),
		SkillInputSpec.from_widget("玩家数量", SkillInputNumber.create(0.0, 5.0, 1.0, 1.0, true)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(SkillNodeSlotConstants.array_type(PortType.CARD_HOLDER), "玩家"),
	]
