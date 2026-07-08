class_name SkillNodeCategoryConstants
extends RefCounted

enum Category {
	EVENT,
	CARD,
	CARD_HOLDER,
	MODIFIER,
	ALGEBRA,
	BOOLEAN,
	ARRAY
}

const ALL: Array[Category] = [
	Category.EVENT,
	Category.CARD,
	Category.CARD_HOLDER,
	Category.MODIFIER,
	Category.ALGEBRA,
	Category.BOOLEAN,
	Category.ARRAY,
]

const TITLEBAR_COLORS: Dictionary = {
	Category.ALGEBRA: Color(0.2627451, 0.49803922, 0.25490198),
	Category.MODIFIER: Color(0.6, 0.3137255, 0.3137255),
	Category.CARD_HOLDER: Color(0.25882354, 0.41960785, 0.5254902),
	Category.CARD: Color(0.5176471, 0.2627451, 0.46666667),
	Category.EVENT: Color(0.35686275, 0.35686275, 0.35686275),
	Category.BOOLEAN: Color(0.5647059, 0.42352942, 0.28235295),
	Category.ARRAY: Color(0.5137255, 0.5647059, 0.28235295),
}

const ICONS: Dictionary = {
	Category.ALGEBRA: preload("res://assets/textures/icons/skills/calc.svg"),
	Category.MODIFIER: preload("res://assets/textures/icons/skills/lightning.svg"),
	Category.CARD_HOLDER: preload("res://assets/textures/icons/skills/holder.svg"),
	Category.CARD: preload("res://assets/textures/icons/skills/card.svg"),
	Category.EVENT: preload("res://assets/textures/icons/skills/event.svg"),
	Category.BOOLEAN: preload("res://assets/textures/icons/skills/boolean.svg"),
	Category.ARRAY: preload("res://assets/textures/icons/skills/array.svg"),
}

const DISPLAY_NAMES: Dictionary = {
	Category.EVENT: "事件",
	Category.CARD: "卡牌",
	Category.CARD_HOLDER: "卡位",
	Category.MODIFIER: "修改器",
	Category.ALGEBRA: "运算",
	Category.BOOLEAN: "布尔",
	Category.ARRAY: "数组",
}

static func get_display_name(category: Category) -> String:
	return DISPLAY_NAMES.get(category, "Unknown")

static func get_icon(type: Category) -> Texture2D:
	if not ICONS.has(type):
		return null
	return ICONS[type] as Texture2D