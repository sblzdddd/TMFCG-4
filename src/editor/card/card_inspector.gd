@tool
extends Container
class_name CardInspector

signal card_changed(card: CardData)

@export var _preview: CardVisual
@export var _character_configurator: CardVisualEditor
@export var _suit_edit: OptionButton
@export var _value_edit: OptionButton
@export var _enable_skill: CheckBox
@export var _skill_settings: Control
@export var _skill_priority: DraggerSpinBox
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


func bind(card: CardData) -> void:
	_loading = true
	_card = card
	if card.visual == null:
		card.visual = CardVisualData.new()

	CardEditUtils.select_suit(_suit_edit, card.suit)
	CardEditUtils.update_value_availability(_value_edit, card.suit, card.rank)
	_enable_skill.button_pressed = card.type == CardData.Type.SKILL
	_skill_priority.value = card.skill_priority
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
	_loading = false


func _on_suit_selected(_index: int) -> void:
	if _loading or _card == null:
		return
	var suit := CardEditUtils.get_selected_suit(_suit_edit)
	_card.suit = suit
	_card.rank = CardEditUtils.update_value_availability(_value_edit, suit, _card.rank)
	_apply_preview()
	_emit_changed()


func _on_value_selected(_index: int) -> void:
	if _loading or _card == null:
		return
	_card.rank = CardEditUtils.get_selected_rank(_value_edit)
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
