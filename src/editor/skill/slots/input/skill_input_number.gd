@tool
class_name SkillInputNumber
extends SkillInputWidget

func get_linked_type() -> SkillNodeSlotConstants.PortType: return SkillNodeSlotConstants.PortType.NUMBER

@export var min_value: float = 0.0
@export var max_value: float = 10.0
@export var step: float = 1.0
@export var value: float = 1.0
@export var rounded: bool = true


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
	var spinbox: DraggerSpinBox = SkillNodeSlotConstants.DRAGGER_SPINBOX_SCENE.instantiate()
	spinbox.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.value = value
	spinbox.rounded = rounded
	spinbox.label_text = label_text
	return spinbox

func apply_to_control(control: Control) -> void:
	if control is SpinBox:
		(control as SpinBox).value = value

func bind_control(control: Control, on_edit_begin: Callable = Callable()) -> void:
	if control is SpinBox:
		var session_active := false
		var begin_edit := func() -> void:
			if session_active:
				return
			session_active = true
			if on_edit_begin.is_valid():
				on_edit_begin.call()
		var end_edit := func() -> void:
			session_active = false
		control.focus_entered.connect(begin_edit)
		control.focus_exited.connect(end_edit)
		if control is DraggerSpinBox:
			var overlay := control.get_node_or_null("DragOverlay")
			if overlay != null:
				overlay.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						begin_edit.call()
				)
		control.value_changed.connect(func(new_value: float) -> void:
			value = new_value
		)

func serialize() -> Dictionary:
	return {
		"kind": "number",
		"value": value,
	}

func deserialize(data: Dictionary) -> void:
	if data.has("value"):
		value = float(data["value"])
