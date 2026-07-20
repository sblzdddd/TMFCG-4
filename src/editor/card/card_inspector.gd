@tool
extends Container
class_name CardInspector

signal card_changed(card: CardData)

const MAX_SKILLS := 4
const _LINE_EDIT_SCENE: PackedScene = preload("res://definitions/prefabs/pre_line_edit.tscn")
const _TEXT_EDIT_SCENE: PackedScene = preload("res://definitions/prefabs/pre_text_edit.tscn")
const _REMOVE_ICON: Texture2D = preload("res://assets/textures/icons/editor/Remove.svg")

@export var _preview: CardVisual
@export var _character_configurator: CardVisualEditor
@export var _suit_edit: OptionButton
@export var _value_edit: OptionButton
@export var _enable_skill: CheckBox
@export var _skill_settings: Control
@export var _skill_priority: DraggerSpinBox
@export var _skill_entries: VBoxContainer
@export var _add_skill_button: Button
@export var _club_icon: Texture2D
@export var _diamond_icon: Texture2D
@export var _heart_icon: Texture2D
@export var _spade_icon: Texture2D

var _card: CardData = null
var _loading := false


func _ready() -> void:
	CardEditUtils.populate_suit_option(
		_suit_edit, _club_icon, _diamond_icon, _heart_icon, _spade_icon
	)
	CardEditUtils.populate_value_option(_value_edit)
	_suit_edit.item_selected.connect(_on_suit_selected)
	_value_edit.item_selected.connect(_on_value_selected)
	_enable_skill.toggled.connect(_on_enable_skill_toggled)
	_skill_priority.value_changed.connect(_on_skill_priority_changed)
	_character_configurator.character_data_changed.connect(_on_character_data_changed)
	if _add_skill_button:
		_add_skill_button.pressed.connect(_on_add_skill_pressed)


func bind(card: CardData) -> void:
	_loading = true
	_card = card
	if card.visual == null:
		card.visual = CardVisualData.new()

	CardEditUtils.select_suit(_suit_edit, card.suit)
	CardEditUtils.update_value_availability(_value_edit, card.suit, card.rank)
	_enable_skill.button_pressed = card.type == CardData.Type.SKILL
	_skill_priority.value = card.skill_priority
	_rebuild_skill_entries()
	_update_skill_settings_visibility()
	_character_configurator.bind(card.visual)
	_apply_preview()
	_loading = false


func clear() -> void:
	_loading = true
	_card = null
	_character_configurator.bind(null)
	_preview.card = null
	_preview.character = null
	_clear_skill_entries()
	_loading = false


func _on_suit_selected(_index: int) -> void:
	if _loading or _card == null:
		return
	var suit := _suit_edit.get_selected_id() as CardEnums.Suit
	_card.suit = suit
	_card.rank = CardEditUtils.update_value_availability(_value_edit, suit, _card.rank)
	_apply_preview()
	_emit_changed()


func _on_value_selected(_index: int) -> void:
	if _loading or _card == null:
		return
	_card.rank = _value_edit.get_selected_id() as CardEnums.Rank
	_apply_preview()
	_emit_changed()


func _on_enable_skill_toggled(enabled: bool) -> void:
	if _loading or _card == null:
		return
	_card.type = CardData.Type.SKILL if enabled else CardData.Type.NORMAL
	_update_skill_settings_visibility()
	_emit_changed()


func _on_skill_priority_changed(_value: float) -> void:
	if _loading or _card == null:
		return
	_card.skill_priority = int(_skill_priority.value)
	_emit_changed()


func _on_character_data_changed(data: CardVisualData) -> void:
	if _loading or _card == null:
		return
	_card.visual = data
	_apply_preview()
	_emit_changed()


func _on_add_skill_pressed() -> void:
	if _loading or _card == null:
		return
	if _card.skills.size() >= MAX_SKILLS:
		return
	_card.skills.append("\n")
	_rebuild_skill_entries()
	_emit_changed()


func _update_skill_settings_visibility() -> void:
	if _skill_settings:
		_skill_settings.visible = _enable_skill.button_pressed


func _apply_preview() -> void:
	if _card == null:
		return
	_preview.card = _card
	_preview.character = _card.visual


func _emit_changed() -> void:
	if _card != null:
		card_changed.emit(_card)


func _clear_skill_entries() -> void:
	if _skill_entries == null:
		return
	while _skill_entries.get_child_count() > 0:
		var child := _skill_entries.get_child(0)
		_skill_entries.remove_child(child)
		child.free()
	_update_add_skill_button()


func _rebuild_skill_entries() -> void:
	_clear_skill_entries()
	if _card == null or _skill_entries == null:
		return
	for i in _card.skills.size():
		_skill_entries.add_child(_make_skill_entry(i, SkillInfo.from_stored(_card.skills[i])))
	_update_add_skill_button()


func _update_add_skill_button() -> void:
	if _add_skill_button == null:
		return
	var count := 0 if _card == null else _card.skills.size()
	_add_skill_button.disabled = count >= MAX_SKILLS


func _make_skill_entry(index: int, info: SkillInfo) -> Control:
	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	entry.add_child(header)

	var name_edit: LabelLineEdit = _LINE_EDIT_SCENE.instantiate()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.label_text = "名称"
	header.add_child(name_edit)
	name_edit.set_text_content(info.name)

	var delete_button := Button.new()
	delete_button.custom_minimum_size = Vector2(32, 0)
	delete_button.icon = _REMOVE_ICON
	delete_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_button.tooltip_text = "删除技能"
	header.add_child(delete_button)

	var desc_edit: LabelLineEdit = _TEXT_EDIT_SCENE.instantiate()
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.custom_minimum_size = Vector2(0, 72)
	desc_edit.label_text = "描述"
	desc_edit.set("wrap_mode", TextEdit.LINE_WRAPPING_BOUNDARY)
	entry.add_child(desc_edit)
	desc_edit.set_text_content(info.description)

	name_edit.text_changed.connect(
		func(_new_text = null) -> void: _on_skill_field_changed(index, name_edit, desc_edit)
	)
	desc_edit.text_changed.connect(
		func(_a = null) -> void: _on_skill_field_changed(index, name_edit, desc_edit)
	)
	delete_button.pressed.connect(func() -> void: _on_delete_skill_pressed(index))

	return entry


func _on_skill_field_changed(
	index: int, name_edit: LabelLineEdit, desc_edit: LabelLineEdit
) -> void:
	if _loading or _card == null:
		return
	if index < 0 or index >= _card.skills.size():
		return
	var info := SkillInfo.new()
	info.name = str(name_edit.get("text"))
	info.description = str(desc_edit.get("text"))
	_card.skills[index] = info.to_stored()
	_emit_changed()


func _on_delete_skill_pressed(index: int) -> void:
	if _loading or _card == null:
		return
	if index < 0 or index >= _card.skills.size():
		return
	_card.skills.remove_at(index)
	_rebuild_skill_entries()
	_emit_changed()
