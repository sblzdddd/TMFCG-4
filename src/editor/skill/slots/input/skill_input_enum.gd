@tool
class_name SkillInputEnum
extends SkillInputWidget

func get_linked_type() -> SkillNodeSlotConstants.PortType: return SkillNodeSlotConstants.PortType.NUMBER

## Display names shown in the option button, in order.
@export var option_names: PackedStringArray = PackedStringArray()
## Integer ids paired with option_names. Empty or short arrays fall back to 0..n-1.
@export var option_ids: PackedInt32Array = PackedInt32Array()
@export var selected_id: int = 0


static func create(
	OptionNames: PackedStringArray = PackedStringArray(),
	OptionIds: PackedInt32Array = PackedInt32Array(),
	SelectedId: int = 0
) -> SkillInputEnum:
	var widget := SkillInputEnum.new()
	widget.option_names = OptionNames
	widget.option_ids = OptionIds
	widget.selected_id = SelectedId
	return widget


func build_widget() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not label_text.is_empty():
		var label := SkillSlotUtils.make_label(label_text, Control.SIZE_SHRINK_BEGIN)
		row.add_child(label)

	var option := OptionButton.new()
	option.name = "OptionButton"
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	_populate_option_button(option)
	_select_id_on_button(option, selected_id)
	row.add_child(option)
	return row


func apply_to_control(control: Control) -> void:
	var option := _find_option_button(control)
	if option == null:
		return
	_populate_option_button(option)
	_select_id_on_button(option, selected_id)


func bind_control(control: Control, on_edit_begin: Callable = Callable()) -> void:
	var option := _find_option_button(control)
	if option == null:
		return
	option.item_selected.connect(func(index: int) -> void:
		if on_edit_begin.is_valid():
			on_edit_begin.call()
		selected_id = option.get_item_id(index)
	)


func serialize() -> Dictionary:
	return {
		"kind": "enum",
		"value": selected_id,
	}


func deserialize(data: Dictionary) -> void:
	if data.has("value"):
		selected_id = int(data["value"])


func get_resolved_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(option_names.size())
	for i in option_names.size():
		if i < option_ids.size():
			ids[i] = option_ids[i]
		else:
			ids[i] = i
	return ids


func _populate_option_button(option: OptionButton) -> void:
	option.clear()
	var ids := get_resolved_ids()
	for i in option_names.size():
		option.add_item(option_names[i], ids[i])


func _select_id_on_button(option: OptionButton, id: int) -> void:
	var index := option.get_item_index(id)
	if index < 0:
		if option.item_count > 0:
			option.select(0)
			selected_id = option.get_item_id(0)
		return
	option.select(index)


func _find_option_button(control: Control) -> OptionButton:
	if control is OptionButton:
		return control as OptionButton
	if control == null:
		return null
	return control.get_node_or_null("OptionButton") as OptionButton
