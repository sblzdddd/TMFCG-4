@tool
class_name OffsetHistoryNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/history.svg")
	node_category = SkillNodeCategory.Category.CARD_HOLDER
	node_name = "按历史顺序获取玩家"
	input_slot_specs = [
		SkillInputSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "当前玩家"),
		SkillInputSpec.from_widget("偏移数量", SkillInputNumber.create(-5.0, 5.0, 1.0, 1.0, true)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "玩家"),
	]
