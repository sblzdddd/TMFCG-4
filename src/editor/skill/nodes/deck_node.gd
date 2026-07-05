@tool
class_name DeckNode extends BaseSkillNode

const PortType := SkillConstants.PortType

func info() -> void:
	icon = preload("res://assets/textures/icons/skills/port.svg")
	node_category = SkillNodeCategory.Category.CARD_HOLDER
	node_name = "牌堆"
	output_slot_specs = [
		SkillSlotSpec.create(PortType.CARD_HOLDER, "牌堆目标"),
	]
