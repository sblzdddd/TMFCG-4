extends VBoxContainer
class_name FilesPanelController

signal resource_selected(metadata: Dictionary)
signal card_selected(deck_path: String, card_index: int)
signal selection_cleared
signal resource_deleted(metadata: Dictionary)

@export var _deck_tree: DeckFileTree
@export var _add_deck_button: Button
@export var _delete_button: Button
@export var _create_deck_dialog: CreateDeckDialog
@export var _add_card_dialog: AddCardDialog
@export var _delete_confirm_dialog: ConfirmationDialog

var _pending_delete: Dictionary = {}
var _pending_add_deck_path: String = ""


func _ready() -> void:
	_add_deck_button.pressed.connect(_create_deck_dialog.popup_dialog)
	_delete_button.pressed.connect(_on_delete_pressed)
	_deck_tree.resource_selected.connect(_on_deck_tree_selected)
	_deck_tree.add_card_requested.connect(_on_add_card_requested)
	_add_card_dialog.card_created.connect(_on_card_created)
	if _delete_confirm_dialog:
		_delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	DeckDataStore.decks_changed.connect(_deck_tree.refresh)


func set_show_builtin_decks(value: bool) -> void:
	_deck_tree.show_builtin = value
	_deck_tree.refresh()


func get_selected_metadata() -> Dictionary:
	return _deck_tree.get_selected_metadata()


func _on_deck_tree_selected(metadata: Dictionary) -> void:
	_emit_selection(metadata)


func _emit_selection(metadata: Dictionary) -> void:
	resource_selected.emit(metadata)
	if metadata.get("type") == "card":
		card_selected.emit(metadata.get("path", ""), int(metadata.get("card_index", -1)))
	else:
		selection_cleared.emit()


func refresh_card_item(deck_path: String, card_index: int) -> void:
	_deck_tree.refresh_card_item(deck_path, card_index)


func _on_add_card_requested(deck_path: String) -> void:
	if deck_path.is_empty() or not DeckDataStore.can_modify(deck_path):
		return
	_pending_add_deck_path = deck_path
	_add_card_dialog.popup_for_deck(deck_path)


func _on_card_created(deck_path: String, suit: CardEnums.Suit, rank: CardEnums.Rank) -> void:
	if deck_path.is_empty():
		deck_path = _pending_add_deck_path
	_pending_add_deck_path = ""
	var new_index := DeckDataStore.add_card(deck_path, suit, rank)
	if new_index < 0:
		return
	_deck_tree.refresh_deck_cards(deck_path)
	_deck_tree.select_card(deck_path, new_index)
	card_selected.emit(deck_path, new_index)


func _on_delete_pressed() -> void:
	var metadata := get_selected_metadata()
	if metadata.is_empty():
		push_warning("Nothing selected to delete.")
		return
	var path: String = metadata.get("path", "")
	if not DeckDataStore.can_modify(path):
		push_warning("Cannot delete built-in resources outside the editor.")
		return
	_pending_delete = metadata
	if _delete_confirm_dialog:
		_delete_confirm_dialog.dialog_text = _delete_message(metadata)
		_delete_confirm_dialog.popup_centered()
	else:
		_on_delete_confirmed()


func _delete_message(metadata: Dictionary) -> String:
	match metadata.get("type"):
		"deck": return "确定删除牌组？此操作无法撤销。"
		"card": return "确定删除该卡牌？"
		_: return "确定删除所选资源？"


func _on_delete_confirmed() -> void:
	var metadata := _pending_delete
	_pending_delete = {}
	match metadata.get("type"):
		"deck":
			DeckDataStore.delete_deck(metadata.get("path", ""))
			resource_deleted.emit(metadata)
		"card":
			var path: String = metadata.get("path", "")
			var idx: int = int(metadata.get("card_index", -1))
			if DeckDataStore.remove_card(path, idx) == OK:
				_deck_tree.refresh_deck_cards(path)
			resource_deleted.emit(metadata)
