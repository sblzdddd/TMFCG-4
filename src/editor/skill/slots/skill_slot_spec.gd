class_name SkillSlotSpec
extends Resource

const PortType := SkillNodeSlotConstants.PortType

enum TypeMode { FIXED, POLYMORPHIC_ARRAY }

@export var type: PortType = PortType.EVENT
@export var label: String = ""
@export var type_mode: TypeMode = TypeMode.FIXED
@export var polymorphic_group: StringName = &"default"

static func create(Type: PortType = PortType.EVENT, LabelText: String = "") -> SkillSlotSpec:
	var spec := SkillSlotSpec.new()
	spec.type = Type
	spec.label = LabelText
	return spec

static func polymorphic_array(LabelText: String, Group: StringName = &"default") -> SkillSlotSpec:
	var spec := create(SkillNodeSlotConstants.array_type(PortType.ANY), LabelText)
	spec.type_mode = TypeMode.POLYMORPHIC_ARRAY
	spec.polymorphic_group = Group
	return spec

func is_polymorphic() -> bool:
	if type_mode == TypeMode.POLYMORPHIC_ARRAY:
		return true
	return SkillNodeSlotConstants.is_any_type(type)

func build_widget() -> Control:
	if label.is_empty():
		return null
	var label_widget := SkillSlotUtils.make_label(label, Control.SIZE_SHRINK_END)
	return label_widget
