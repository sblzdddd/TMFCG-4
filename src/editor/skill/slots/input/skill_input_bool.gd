@tool
class_name SkillInputBool
extends SkillInputWidget

func get_linked_type() -> SkillNodeSlotConstants.PortType: return SkillNodeSlotConstants.PortType.BOOLEAN

@export var pressed: bool = false


static func create(Pressed: bool = false) -> SkillInputBool:
	var widget := SkillInputBool.new()
	widget.pressed = Pressed
	return widget


func build_widget() -> Control:
	var checkbox := CheckBox.new()
	checkbox.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkbox.text = label_text
	checkbox.button_pressed = pressed
	return checkbox

func apply_to_control(control: Control) -> void:
	if control is CheckBox:
		(control as CheckBox).button_pressed = pressed

func bind_control(control: Control, on_edit_begin: Callable = Callable()) -> void:
	if control is CheckBox:
		(control as CheckBox).pressed.connect(func() -> void:
			if on_edit_begin.is_valid():
				on_edit_begin.call()
		)
		(control as CheckBox).toggled.connect(func(new_pressed: bool) -> void:
			pressed = new_pressed
		)

func serialize() -> Dictionary:
	return {
		"kind": "bool",
		"pressed": pressed,
	}

func deserialize(data: Dictionary) -> void:
	if data.has("pressed"):
		pressed = bool(data["pressed"])