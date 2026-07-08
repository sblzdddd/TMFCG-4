@tool
class_name SkillInputString
extends SkillInputWidget

func get_linked_type() -> SkillNodeSlotConstants.PortType: return SkillNodeSlotConstants.PortType.STRING

@export var placeholder: String = ""
@export var value: String = ""

func build_widget() -> Control:
	var line_edit := LineEdit.new()
	line_edit.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	line_edit.placeholder_text = placeholder
	line_edit.text = value
	return line_edit

func apply_to_control(control: Control) -> void:
	if control is LineEdit:
		(control as LineEdit).text = value

func bind_control(control: Control, on_edit_begin: Callable = Callable()) -> void:
	if control is LineEdit:
		var session_active := false
		var begin_edit := func() -> void:
			if session_active:
				return
			session_active = true
			if on_edit_begin.is_valid():
				on_edit_begin.call()
		control.focus_entered.connect(begin_edit)
		control.focus_exited.connect(func() -> void:
			session_active = false
		)
		(control as LineEdit).text_changed.connect(func(new_text: String) -> void:
			value = new_text
		)

func serialize() -> Dictionary:
	return {
		"kind": "string",
		"value": value,
	}

func deserialize(data: Dictionary) -> void:
	if data.has("value"):
		value = String(data["value"])
