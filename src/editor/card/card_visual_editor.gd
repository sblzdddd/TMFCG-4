extends Container
class_name CardVisualEditor

signal character_data_changed(data: CardVisualData)

@export var _picker_dialog: CharacterPickerDialog
@export var _select_button: OptionButton
@export var _name_info: Label
@export var _description_label: Label
@export var _portrait: TextureRect
@export var _x_edit: ValueEdit
@export var _y_edit: ValueEdit
@export var _scale_edit: ValueEdit
@export var _reset_button: Button
@export var _character_editor_button: Button   # TODO

var selected_character: CardVisualData = null


func _ready() -> void:
	TranslationServer.set_locale("zh")
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_select_button.item_selected.connect(_on_select_item_selected)
	_picker_dialog.character_selected.connect(_on_character_selected)
	_x_edit.value_changed.connect(_on_transform_changed)
	_y_edit.value_changed.connect(_on_transform_changed)
	_scale_edit.value_changed.connect(_on_transform_changed)
	_reset_button.pressed.connect(_on_reset_pressed)


func _on_select_item_selected(index: int) -> void:
	var item_id := _select_button.get_item_id(index)
	if item_id == 0:
		return
	match item_id:
		1:
			_picker_dialog.popup_preset_picker()
		2:
			_picker_dialog.popup_user_picker()
	_select_button.select(0)


func _on_character_selected(character: DialogicCharacter) -> void:
	if selected_character == null:
		selected_character = CardVisualData.new()
	selected_character.character = character
	_sync_transform_from_edits()
	_apply_character(character)
	character_data_changed.emit(selected_character)


func _apply_character(character: DialogicCharacter) -> void:
	var display_name := character.get_display_name_translated()
	if display_name.is_empty():
		display_name = character.get_character_name()

	_name_info.text = display_name
	var card_description := CharacterUtils.get_card_description(character)
	_description_label.text = (
		card_description if not card_description.is_empty() else "【无角色描述】"
	)

	var texture := CharacterUtils.get_preview_texture(character)
	if texture != null:
		_portrait.texture = texture


func _on_transform_changed(_new_value: float = 0.0) -> void:
	if selected_character == null:
		return
	_sync_transform_from_edits()
	character_data_changed.emit(selected_character)


func _sync_transform_from_edits() -> void:
	selected_character.transform.x = _x_edit.value
	selected_character.transform.y = _y_edit.value
	selected_character.transform.z = _scale_edit.value


func _on_reset_pressed() -> void:
	_x_edit.value = 0.0
	_y_edit.value = 0.0
	_scale_edit.value = 1.0
