class_name SkillNodeSlotConstants
extends RefCounted

enum PortType {
	CARD_ARRAY = -6,
	CARD_HOLDER_ARRAY = -5,
	STRING_ARRAY = -4,
	BOOLEAN_ARRAY = -3,
	NUMBER_ARRAY = -2,
	EVENT_ARRAY = -1,
	UNDEFINED = 0,
	EVENT = 1,
	NUMBER = 2,
	BOOLEAN = 3,
	STRING = 4,
	CARD_HOLDER = 5,
	CARD = 6,
}

const PORT_ARRAY_ICON: Texture2D = preload("res://assets/textures/icons/skills/port_array.svg")

const DRAGGER_SPINBOX_SCENE: PackedScene = preload("res://definitions/prefabs/pre_dragger_spinbox.tscn")
const ROW_MIN_HEIGHT := 33

const TYPE_INFO: Dictionary = {
	PortType.UNDEFINED: {
		"name": "Undefined",
		"color": Color(0.0, 0.0, 0.0, 0.0),
		"icon": null,
	},
	PortType.EVENT: {
		"name": "Event",
		"color": Color(1.0, 1.0, 1.0, 1.0),
		"icon": null,
	},
	PortType.NUMBER: {
		"name": "Number",
		"color": Color(0.3372549, 1.0, 0.44705883, 1.0),
		"icon": null,
	},
	PortType.BOOLEAN: {
		"name": "Boolean",
		"color": Color(1.0, 0.8392157, 0.3372549, 1.0),
		"icon": null,
	},
	PortType.CARD_HOLDER: {
		"name": "CardHolder",
		"color": Color(0.2784314, 0.7372549, 1.0, 1.0),
		"icon": null,
	},
	PortType.CARD: {
		"name": "Card",
		"color": Color(1.0, 0.373, 0.922, 1.0),
		"icon": null,
	},
}


static func base_type(type: int) -> int:
	return absi(type)


static func is_array_type(type: int) -> bool:
	return type < 0


static func array_type(single_type: int) -> int:
	return -base_type(single_type)


static func get_type_info(type: int) -> Dictionary:
	var key := base_type(type)
	if not TYPE_INFO.has(key):
		return {}
	return TYPE_INFO[key]


static func get_color(type: int) -> Color:
	var info := get_type_info(type)
	if info.is_empty():
		return Color.WHITE
	return info["color"]


static func get_icon(type: int) -> Texture2D:
	if is_array_type(type):
		return PORT_ARRAY_ICON
	var info := get_type_info(type)
	if info.is_empty():
		return null
	return info.get("icon")


static func get_display_name(type: int) -> String:
	var info := get_type_info(type)
	if info.is_empty():
		return "Unknown"
	var name: String = info["name"]
	if is_array_type(type):
		return "%s[]" % name
	return name


static func graph_port_type(type: int) -> int:
	return base_type(type)


static func types_compatible(a: int, b: int) -> bool:
	if a == PortType.UNDEFINED or b == PortType.UNDEFINED:
		return false
	return base_type(a) == base_type(b)


static func build_type_names() -> Dictionary:
	var names := {}
	for key: int in TYPE_INFO.keys():
		var info: Dictionary = TYPE_INFO[key]
		var singular: String = info["name"]
		names[key] = singular
		names[-key] = "%s[]" % singular
	return names
