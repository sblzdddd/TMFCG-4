@tool
extends Container
class_name CardVisualEditor

signal character_data_changed(data: CardVisualData)

@export var _picker_dialog: CharacterPickerDialog
@export var _select_button: Button
@export var _variant_selection: OptionButton
@export var _variant_prev: Button
@export var _variant_next: Button
@export var _name_info: Label
@export var _description_label: Label
@export var _x_edit: DraggerSpinBox
@export var _y_edit: DraggerSpinBox
@export var _scale_edit: DraggerSpinBox
@export var _reset_button: Button
@export var _set_default_button: Button

var selected_character: CardVisualData = null
var _portrait_keys: Array[String] = []
var _loading := false

const _SET_DEFAULT_BUTTON_TEXT := "设为角色默认变换"


func bind(data: CardVisualData) -> void:
	_loading = true
	selected_character = data
	if data == null:
		_name_info.text = ""
		_description_label.text = ""
		_x_edit.value = 0.0
		_y_edit.value = 0.0
		_scale_edit.value = 1.0
		_refresh_variant_list()
		_update_set_default_button_text()
		_loading = false
		return

	_x_edit.set_block_signals(true)
	_y_edit.set_block_signals(true)
	_scale_edit.set_block_signals(true)
	_x_edit.value = data.transform.x
	_y_edit.value = data.transform.y
	_scale_edit.value = data.transform.z
	_x_edit.set_block_signals(false)
	_y_edit.set_block_signals(false)
	_scale_edit.set_block_signals(false)
	if data.character != null:
		_apply_character(data.character)
	else:
		_name_info.text = ""
		_description_label.text = ""
	_refresh_variant_list()
	_update_set_default_button_text()
	_loading = false


func _ready() -> void:
	_select_button.pressed.connect(_on_select_button_pressed)
	_variant_selection.item_selected.connect(_on_variant_selected)
	_variant_prev.pressed.connect(_on_variant_prev_pressed)
	_variant_next.pressed.connect(_on_variant_next_pressed)
	_picker_dialog.character_selected.connect(_on_character_selected)
	_x_edit.value_changed.connect(_on_transform_changed)
	_y_edit.value_changed.connect(_on_transform_changed)
	_scale_edit.value_changed.connect(_on_transform_changed)
	_reset_button.pressed.connect(_apply_default_transform)
	if _set_default_button:
		_set_default_button.visible = ResourceFsUtils.can_write_presets()
		_set_default_button.pressed.connect(_on_set_default_button_pressed)
		_set_default_button.text = _SET_DEFAULT_BUTTON_TEXT
	_refresh_variant_list()


func _on_select_button_pressed() -> void:
	_picker_dialog.popup_picker()


func _on_character_selected(character: DialogicCharacter) -> void:
	if _loading:
		return
	if selected_character == null:
		selected_character = CardVisualData.new()
	selected_character.character = character
	selected_character.portrait = character.default_portrait
	if selected_character.portrait.is_empty() and not character.portraits.is_empty():
		var keys := character.portraits.keys()
		keys.sort()
		selected_character.portrait = keys[0]
	_apply_character_default_transform(character)
	_apply_edit_transform()
	_apply_character(character)
	_refresh_variant_list()
	_update_set_default_button_text()
	character_data_changed.emit(selected_character)


func _apply_character(character: DialogicCharacter) -> void:
	var display_name := character.get_display_name_translated()
	if display_name.is_empty():
		display_name = character.get_character_name()

	_name_info.text = display_name
	var card_description := character.extra_config["description"]
	_description_label.text = (
		card_description if not card_description.is_empty() else "【无角色描述】"
	)


func _refresh_variant_list() -> void:
	_variant_selection.clear()
	_portrait_keys.clear()

	if selected_character == null or selected_character.character == null:
		_variant_selection.add_item("选择差分", 0)
		_variant_selection.set_item_disabled(0, true)
		_set_variant_buttons_enabled(false)
		return

	var character := selected_character.character
	_portrait_keys.assign(character.portraits.keys())
	_portrait_keys.sort()

	var current_portrait := selected_character.portrait
	if current_portrait.is_empty():
		current_portrait = character.default_portrait
	if current_portrait.is_empty() and not _portrait_keys.is_empty():
		current_portrait = _portrait_keys[0]

	var selected_index := 0
	for i in range(_portrait_keys.size()):
		_variant_selection.add_item(_portrait_keys[i], i)
		if _portrait_keys[i] == current_portrait:
			selected_index = i

	if _portrait_keys.is_empty():
		_variant_selection.add_item("无差分", 0)
		_variant_selection.set_item_disabled(0, true)
		_set_variant_buttons_enabled(false)
		return

	_variant_selection.set_block_signals(true)
	_variant_selection.select(selected_index)
	_variant_selection.set_block_signals(false)
	selected_character.portrait = _portrait_keys[selected_index]
	_set_variant_buttons_enabled(_portrait_keys.size() > 1)


func _set_variant_buttons_enabled(enabled: bool) -> void:
	_variant_selection.disabled = not enabled
	_variant_prev.disabled = not enabled
	_variant_next.disabled = not enabled


func _on_variant_selected(index: int) -> void:
	_select_portrait(index)


func _on_variant_prev_pressed() -> void:
	if _portrait_keys.is_empty(): return
	_select_portrait((_variant_selection.selected - 1 + _portrait_keys.size()) % _portrait_keys.size())


func _on_variant_next_pressed() -> void:
	if _portrait_keys.is_empty(): return
	_select_portrait((_variant_selection.selected + 1) % _portrait_keys.size())


func _select_portrait(index: int) -> void:
	if selected_character == null or index < 0 or index >= _portrait_keys.size():
		return

	var portrait_key := _portrait_keys[index]
	if (
		selected_character.portrait == portrait_key
		and _variant_selection.selected == index
	): return

	selected_character.portrait = portrait_key
	if _variant_selection.selected != index:
		_variant_selection.select(index)
	character_data_changed.emit(selected_character)


func _on_transform_changed(_new_value: float = 0.0) -> void:
	if _loading or selected_character == null:
		return
	_apply_edit_transform()
	_update_set_default_button_text()
	character_data_changed.emit(selected_character)


func _apply_edit_transform() -> void:
	selected_character.transform.x = _x_edit.value
	selected_character.transform.y = _y_edit.value
	selected_character.transform.z = _scale_edit.value


func _apply_default_transform() -> void:
	_x_edit.value = 0.0
	_y_edit.value = 0.0
	_scale_edit.value = 1.0
	_on_transform_changed()


func _apply_character_default_transform(character: DialogicCharacter) -> void:
	_x_edit.set_block_signals(true)
	_y_edit.set_block_signals(true)
	_scale_edit.set_block_signals(true)
	_x_edit.value = character.offset.x
	_y_edit.value = character.offset.y
	_scale_edit.value = character.scale
	_x_edit.set_block_signals(false)
	_y_edit.set_block_signals(false)
	_scale_edit.set_block_signals(false)


func _on_set_default_button_pressed() -> void:
	if selected_character == null or selected_character.character == null:
		return

	var character := selected_character.character
	var path := character.resource_path
	if path.is_empty():
		push_warning("Cannot save default transform: character has no resource path.")
		return

	character.offset = Vector2(_x_edit.value, _y_edit.value)
	character.scale = _scale_edit.value

	if CharacterDataStore.save_character(character, path) != OK:
		return
	_update_set_default_button_text()


func _update_set_default_button_text() -> void:
	if _set_default_button == null:
		return
	var text := _SET_DEFAULT_BUTTON_TEXT
	if (
		selected_character != null
		and selected_character.character != null
		and _transform_differs_from_character_default()
	):
		text += "*"
	_set_default_button.text = text


func _transform_differs_from_character_default() -> bool:
	var character := selected_character.character
	return (
		not is_equal_approx(_x_edit.value, character.offset.x)
		or not is_equal_approx(_y_edit.value, character.offset.y)
		or not is_equal_approx(_scale_edit.value, character.scale)
	)
