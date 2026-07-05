@tool
class_name RandomPlayerNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/random.svg")
	node_category = SkillNodeCategory.Category.CARD_HOLDER
	node_name = "随机玩家"
	input_slot_specs = [
		SkillInputSpec.spacer(),
		SkillInputSpec.from_widget("随机数量", SkillInputNumber.create(1.0, 5.0, 1.0, 1.0, true)),
		SkillInputSpec.from_widget("包含被冻结的玩家", SkillInputBool.create(false)),
	]
	output_slot_specs = [
		SkillSlotSpec.create(SkillConstants.array_type(PortType.CARD_HOLDER), "玩家"),
	]
