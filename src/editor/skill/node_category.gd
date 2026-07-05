class_name SkillNodeCategory
extends RefCounted

enum Category {
	EVENT,
	CARD,
	CARD_HOLDER,
	MODIFIER,
	ALGEBRA,
}

const TITLEBAR_COLORS: Dictionary = {
	Category.ALGEBRA: Color(0.36078432, 0.49803922, 0.25490198),
	Category.MODIFIER: Color(0.6, 0.3137255, 0.3137255),
	Category.CARD_HOLDER: Color(0.25882354, 0.41960785, 0.5254902),
	Category.CARD: Color(0.5176471, 0.2627451, 0.46666667),
	Category.EVENT: Color(0.35686275, 0.35686275, 0.35686275),
}
