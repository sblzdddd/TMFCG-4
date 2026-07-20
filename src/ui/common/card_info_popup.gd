class_name CardInfoPopup
extends PanelContainer
## Mouse-following card info overlay. Share one instance across card hover sources.

const SKILL_NAME_COLOR := Color(1.0, 0.8091763, 0.8438715, 1.0)
const MOUSE_OFFSET := Vector2(16, 16)
const POPUP_WIDTH := 220.0

@onready var _text: RichTextLabel = $CardInfoMargin/CardInfoText


func _ready() -> void:
	set_process(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	if _text != null:
		_text.custom_minimum_size = Vector2(POPUP_WIDTH - 16.0, 0)
		_text.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_text.fit_content = true
		_text.scroll_active = false
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(child as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_position()


func show_card(card_data: CardData) -> void:
	if _text == null:
		return
	_text.text = format_card_info_bbcode(card_data)
	visible = true
	_fit_to_content()
	_update_position()
	set_process(true)


func hide_popup() -> void:
	visible = false
	set_process(false)


static func format_card_info_bbcode(card_data: CardData) -> String:
	if card_data == null:
		return ""
	var suit := CardEnums.suit_display_name(card_data.suit)
	var value := CardUtils.rank_display(card_data.rank)
	var lines: PackedStringArray = []
	var character_name := ""
	if card_data.visual != null and card_data.visual.character != null:
		character_name = card_data.visual.character.display_name
	if character_name.is_empty():
		lines.append("%s %s" % [suit, value])
	else:
		lines.append("%s %s [%s]" % [suit, value, character_name])

	var skills := card_data.skill_info
	if skills.is_empty():
		return "\n".join(lines)

	lines.append("")
	var color_hex := SKILL_NAME_COLOR.to_html(false)
	for i in skills.size():
		var skill: SkillInfo = skills[i]
		if i > 0:
			lines.append("")
			lines.append("[hr]")
			lines.append("")
		var skill_name := skill.name if not skill.name.is_empty() else "未命名技能"
		lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [color_hex, skill_name])
		if not skill.description.is_empty():
			lines.append(skill.description)
	return "\n".join(lines)


func _update_position() -> void:
	var mouse := get_viewport().get_mouse_position() + MOUSE_OFFSET
	var panel_size := size
	if panel_size.y <= 0.0:
		panel_size = get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	mouse.x = clampf(mouse.x, 0.0, maxf(viewport_size.x - panel_size.x, 0.0))
	mouse.y = clampf(mouse.y, 0.0, maxf(viewport_size.y - panel_size.y, 0.0))
	global_position = mouse


func _fit_to_content() -> void:
	if _text == null:
		return
	_text.custom_minimum_size.x = POPUP_WIDTH - 16.0
	var text_height := _text.get_content_height()
	_text.custom_minimum_size.y = text_height
	reset_size()
	size = get_combined_minimum_size()
