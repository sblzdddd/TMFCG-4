class_name SkillNodeSlotConstants
extends RefCounted

enum PortType {
	ANY_ARRAY = -1000,
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
	ANY = 1000,
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
	PortType.ANY: {
		"name": "Any",
		"color": Color(0.38431373, 0.38431373, 0.38431373),
		"icon": null,
	}
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


static func effective_type(spec: SkillSlotSpec, instance_state: SkillNodeInstanceState) -> int:
	if spec == null:
		return PortType.UNDEFINED
	var resolved := resolved_types(instance_state)
	return SkillPolymorphicUtils.effective_type(spec, resolved)


static func resolved_types(instance_state: SkillNodeInstanceState) -> Dictionary:
	if instance_state == null:
		return {}
	return instance_state.polymorphic_types


static func is_any_type(type: int) -> bool:
	return type == PortType.ANY or type == PortType.ANY_ARRAY


static func graph_port_type(type: int) -> int:
	if is_any_type(type):
		return PortType.ANY
	return base_type(type)


static func types_compatible(a: int, b: int) -> bool:
	if a == PortType.UNDEFINED or b == PortType.UNDEFINED:
		return false
	if is_any_type(a) or is_any_type(b):
		if is_any_type(a) and is_any_type(b):
			return is_array_type(a) == is_array_type(b)
		var any_side: int = a if is_any_type(a) else b
		var concrete: int = b if is_any_type(a) else a
		if any_side == PortType.ANY_ARRAY:
			return _concrete_compatible_with_polymorphic_array(concrete)
		return true
	return base_type(a) == base_type(b)


static func _concrete_compatible_with_polymorphic_array(concrete: int) -> bool:
	if concrete == PortType.UNDEFINED:
		return false
	if concrete == PortType.EVENT or concrete == PortType.EVENT_ARRAY:
		return false
	return true


static func build_type_names() -> Dictionary:
	var names := {}
	for key: int in TYPE_INFO.keys():
		var info: Dictionary = TYPE_INFO[key]
		var singular: String = info["name"]
		names[key] = singular
		names[-key] = "%s[]" % singular
	return names
