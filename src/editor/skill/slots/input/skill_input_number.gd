@tool
class_name SkillInputNumber
extends SkillInputWidget

func get_linked_type() -> SkillConstants.PortType: return SkillConstants.PortType.NUMBER

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
@export var value: float = 0.0
@export var rounded: bool = false


static func create(
	min_value: float = 0.0,
	max_value: float = 100.0,
	step: float = 1.0,
	value: float = 0.0,
	rounded: bool = false
) -> SkillInputNumber:
	var widget := SkillInputNumber.new()
	widget.min_value = min_value
	widget.max_value = max_value
	widget.step = step
	widget.value = value
	widget.rounded = rounded
	return widget


func build_widget() -> Control:
	var spinbox: DraggerSpinBox = SkillConstants.DRAGGER_SPINBOX_SCENE.instantiate()
	spinbox.custom_minimum_size.y = SkillConstants.ROW_MIN_HEIGHT
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.value = value
	spinbox.rounded = rounded
	spinbox.label_text = label_text
	return spinbox
