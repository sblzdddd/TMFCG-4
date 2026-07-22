class_name DeckVisibleListPopup
extends PanelContainer
## Below-deck list of viewer-visible cards (suit/rank, character, depth).

const POPUP_WIDTH := 240.0
const GAP_BELOW := 8.0


@onready var _text: RichTextLabel = $Margin/ListText

var _entries: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Overlay below DeckPile center — not an HBox sibling, so the pile stays put.
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	_apply_bottom_offsets(40.0)
	if _text != null:
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text.fit_content = true
		_text.scroll_active = false
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.bbcode_enabled = true


func set_entries(entries: Array[Dictionary]) -> void:
	_entries = entries.duplicate()
	if visible:
		_refresh_text()


func show_list() -> void:
	if _entries.is_empty():
		hide_list()
		return
	_refresh_text()
	visible = true


func hide_list() -> void:
	visible = false


func _refresh_text() -> void:
	if _text == null:
		return
	var lines: PackedStringArray = []
	for entry in _entries:
		var card: Card = entry.get("card") as Card
		var depth := int(entry.get("depth", 0))
		if card == null:
			continue
		lines.append(_format_line(card, depth))
	_text.text = "\n".join(lines)
	_fit_to_content()


static func _format_line(card: Card, depth: int) -> String:
	var suit := CardEnums.suit_display_name(card.suit)
	var value := CardUtils.rank_display(card.rank)
	var character_name := ""
	if card.data != null and card.data.visual != null and card.data.visual.character != null:
		character_name = str(card.data.visual.character.display_name)
	var label := "%s %s" % [suit, value]
	if not character_name.is_empty():
		label = "%s [%s]" % [label, character_name]
	return "%d before · %s" % [depth, label]


func _fit_to_content() -> void:
	if _text == null:
		return
	_text.custom_minimum_size.x = POPUP_WIDTH - 16.0
	var text_height := _text.get_content_height()
	_text.custom_minimum_size.y = text_height
	reset_size()
	size = get_combined_minimum_size()
	_apply_bottom_offsets(size.y)


func _apply_bottom_offsets(height: float) -> void:
	var half_w := size.x * 0.5 if size.x > 0.0 else POPUP_WIDTH * 0.5
	offset_left = -half_w
	offset_right = half_w
	offset_top = GAP_BELOW
	offset_bottom = GAP_BELOW + height
