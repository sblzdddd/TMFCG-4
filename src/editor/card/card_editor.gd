@tool
extends Control
class_name CardEditor

@export var _inspector: CardInspector
@export var _file_tree: EditorFileTree
@export var _skill_graph: SkillGraph
@export var _add_deck_button: Button
@export var _add_character_button: Button
@export var _delete_button: Button
@export var _create_deck_dialog: CreateDeckDialog
@export var _create_character_dialog: CreateCharacterDialog
@export var _add_card_dialog: AddCardDialog
@export var _delete_confirm_dialog: ConfirmationDialog

var _active_deck_path: String = ""
var _active_card_index: int = -1
var _active_deck: DeckData = null
var _loading := false
var _pending_delete_metadata: Dictionary = {}
var _pending_add_deck_path: String = ""


func _ready() -> void:
	if Engine.is_embedded_in_editor():
		print("CardEditor is running inside the editor viewport.")
		get_window().content_scale_factor = 1.15

	_add_deck_button.pressed.connect(_create_deck_dialog.popup_dialog)
	_add_character_button.pressed.connect(_create_character_dialog.popup_dialog)
	_delete_button.pressed.connect(_on_delete_pressed)
	_create_deck_dialog.deck_created.connect(_on_deck_created)
	_create_character_dialog.character_created.connect(_on_character_created)
	_file_tree.resource_selected.connect(_on_resource_selected)
	_file_tree.add_card_requested.connect(_on_add_card_requested)
	_add_card_dialog.card_created.connect(_on_card_created)
	_inspector.card_changed.connect(_on_card_changed)
	_skill_graph.graph_changed.connect(_on_skill_graph_changed)
	if _delete_confirm_dialog:
		_delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)

	_clear_editor()


func _on_deck_created(_deck: DeckData, _path: String) -> void:
	_file_tree.refresh()


func _on_character_created(_character: DialogicCharacter, _path: String) -> void:
	_file_tree.refresh()


func _on_resource_selected(metadata: Dictionary) -> void:
	if metadata.is_empty():
		_clear_editor()
		return
	match metadata.get("type"):
		"card":
			_select_card(metadata.get("path", ""), int(metadata.get("card_index", -1)))
		_:
			_clear_editor()


func _select_card(deck_path: String, card_index: int) -> void:
	if deck_path.is_empty() or card_index < 0:
		_clear_editor()
		return

	if _active_deck_path == deck_path and _active_card_index == card_index:
		return

	_flush_active_card()

	var deck := load(deck_path) as DeckData
	if deck == null or card_index >= deck.cards.size():
		_clear_editor()
		return

	_active_deck_path = deck_path
	_active_card_index = card_index
	_active_deck = deck

	_loading = true
	var card := deck.cards[card_index]
	_inspector.bind(card)
	_skill_graph.read_only = false
	_skill_graph.set_loading(true)
	SkillGraphSerializer.deserialize_graph(_skill_graph, card.skill_graph)
	_skill_graph.set_loading(false)
	_loading = false


func _flush_active_card() -> void:
	if _loading or _active_deck == null or _active_card_index < 0:
		return
	_persist_active_card()


func _persist_active_card() -> void:
	if _active_deck == null or _active_card_index < 0:
		return

	var card := _active_deck.cards[_active_card_index]
	card.skill_graph = SkillGraphSerializer.serialize_graph(_skill_graph)
	_active_deck.date_modified = Time.get_unix_time_from_system()
	var err := ResourceFsUtils.save_resource(_active_deck, _active_deck_path)
	if err != OK:
		push_error("Failed to save deck: %s" % error_string(err))
		return
	_file_tree.refresh_card_item(_active_deck_path, _active_card_index)


func _on_card_changed(_card: CardData) -> void:
	if _loading:
		return
	_persist_active_card()


func _on_skill_graph_changed() -> void:
	if _loading or _active_deck == null:
		return
	_persist_active_card()


func _clear_editor() -> void:
	_active_deck_path = ""
	_active_card_index = -1
	_active_deck = null
	_inspector.clear()
	_skill_graph.read_only = true
	_skill_graph.set_loading(true)
	SkillGraphSerializer.deserialize_graph(_skill_graph, {})
	_skill_graph.set_loading(false)


func _on_add_card_requested(deck_path: String) -> void:
	if deck_path.is_empty():
		return
	_pending_add_deck_path = deck_path
	_add_card_dialog.popup_for_deck(deck_path)


func _on_card_created(deck_path: String, suit: CardEnums.Suit, rank: CardEnums.Rank) -> void:
	if deck_path.is_empty():
		deck_path = _pending_add_deck_path
	_pending_add_deck_path = ""
	if deck_path.is_empty():
		return

	_flush_active_card()

	var deck := load(deck_path) as DeckData
	if deck == null:
		return

	var card := CardUtils.create_card(suit, rank)
	card.cardId = "card-%d-%d-%d" % [deck.cards.size(), int(suit), int(rank)]
	deck.cards.append(card)
	deck.date_modified = Time.get_unix_time_from_system()
	var err := ResourceFsUtils.save_resource(deck, deck_path)
	if err != OK:
		push_error("Failed to save deck: %s" % error_string(err))
		return

	var new_index := deck.cards.size() - 1
	_file_tree.refresh_deck_cards(deck_path)
	_file_tree.select_card(deck_path, new_index)
	_select_card(deck_path, new_index)


func _on_delete_pressed() -> void:
	var metadata := _file_tree.get_selected_metadata()
	if metadata.is_empty():
		push_warning("Nothing selected to delete.")
		return

	var resource_type: String = metadata.get("type", "")
	var path: String = metadata.get("path", "")
	if resource_type == "card":
		if not ResourceFsUtils.can_delete(path):
			push_warning("Cannot delete cards from this deck.")
			return
	elif not ResourceFsUtils.can_delete(path):
		push_warning("Cannot delete built-in resources outside the editor.")
		return

	_pending_delete_metadata = metadata
	if _delete_confirm_dialog:
		_delete_confirm_dialog.dialog_text = _delete_message(metadata)
		_delete_confirm_dialog.popup_centered()
	else:
		_on_delete_confirmed()


func _delete_message(metadata: Dictionary) -> String:
	match metadata.get("type"):
		"deck":
			return "确定删除牌组？此操作无法撤销。"
		"card":
			return "确定删除该卡牌？"
		"character":
			return "确定删除该角色？"
		_:
			return "确定删除所选资源？"


func _on_delete_confirmed() -> void:
	var metadata := _pending_delete_metadata
	_pending_delete_metadata = {}
	if metadata.is_empty():
		return

	match metadata.get("type"):
		"deck":
			_delete_deck(metadata)
		"card":
			_delete_card(metadata)
		"character":
			_delete_character(metadata)


func _delete_deck(metadata: Dictionary) -> void:
	var path: String = metadata.get("path", "")
	if path == _active_deck_path:
		_clear_editor()
	var err := ResourceFsUtils.delete_resource(path)
	if err != OK:
		push_error("Failed to delete deck: %s" % error_string(err))
		return
	_file_tree.refresh()


func _delete_card(metadata: Dictionary) -> void:
	var deck_path: String = metadata.get("path", "")
	var card_index: int = int(metadata.get("card_index", -1))
	var deck := load(deck_path) as DeckData
	if deck == null or card_index < 0 or card_index >= deck.cards.size():
		return

	if deck_path == _active_deck_path and card_index == _active_card_index:
		_clear_editor()
	elif deck_path == _active_deck_path and card_index < _active_card_index:
		_active_card_index -= 1

	deck.cards.remove_at(card_index)
	deck.date_modified = Time.get_unix_time_from_system()
	var err := ResourceFsUtils.save_resource(deck, deck_path)
	if err != OK:
		push_error("Failed to save deck after card deletion: %s" % error_string(err))
		return

	if deck_path == _active_deck_path:
		_active_deck = deck
		if _active_card_index >= 0 and _active_card_index < deck.cards.size():
			_select_card(deck_path, _active_card_index)

	_file_tree.refresh_deck_cards(deck_path)


func _delete_character(metadata: Dictionary) -> void:
	var path: String = metadata.get("path", "")
	var err := ResourceFsUtils.delete_resource(path)
	if err != OK:
		push_error("Failed to delete character: %s" % error_string(err))
		return
	_file_tree.refresh()
