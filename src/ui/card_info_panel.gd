extends CanvasLayer
## Global card info overlay. Autoload name: CardInfoPanel.

var _popup: CardInfoPopup
var _source_id := 0


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_popup = $Popup as CardInfoPopup


func show_card(
	card_data: CardData, anchor_rect: Rect2 = Rect2(), source: Object = null
) -> void:
	if _popup == null:
		_popup = $Popup as CardInfoPopup
	if _popup == null:
		return
	_source_id = source.get_instance_id() if source != null else 0
	_popup.show_card(card_data, anchor_rect)


func hide_popup(source: Object = null) -> void:
	if _popup == null:
		_popup = get_node_or_null("Popup") as CardInfoPopup
	if _popup == null:
		return
	if source != null and _source_id != 0 and source.get_instance_id() != _source_id:
		return
	_source_id = 0
	_popup.hide_popup()
