@tool
extends Node
class_name CardSession

@export var _inspector: CardInspector
@export var _skill_graph: SkillGraph

var _files_panel: FilesPanelController
var _active_deck_path: String = ""
var _active_card_index: int = -1
var _active_deck: DeckData = null
var _loading := false


func _ready() -> void:
	if _inspector:
		_inspector.card_changed.connect(_on_card_changed)
	if _skill_graph:
		_skill_graph.graph_changed.connect(_on_skill_graph_changed)
	clear()


func bind_files_panel(panel: FilesPanelController) -> void:
	_files_panel = panel


func handle_resource_deleted(metadata: Dictionary) -> void:
	match metadata.get("type"):
		"deck":
			if metadata.get("path", "") == _active_deck_path:
				clear()
		"card":
			var deck_path: String = metadata.get("path", "")
			var card_index: int = int(metadata.get("card_index", -1))
			if deck_path != _active_deck_path:
				return
			if card_index == _active_card_index:
				clear()
			elif card_index < _active_card_index:
				_active_card_index -= 1
				_active_deck = DeckDataStore.load_deck(deck_path)


func select_card(deck_path: String, card_index: int) -> void:
	if deck_path.is_empty() or card_index < 0:
		clear()
		return
	if _active_deck_path == deck_path and _active_card_index == card_index:
		return

	_flush_active_card()
	var deck := DeckDataStore.load_deck(deck_path)
	if deck == null or card_index >= deck.cards.size():
		clear()
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


func clear() -> void:
	_active_deck_path = ""
	_active_card_index = -1
	_active_deck = null
	if _inspector:
		_inspector.clear()
	if _skill_graph:
		_skill_graph.read_only = true
		_skill_graph.set_loading(true)
		SkillGraphSerializer.deserialize_graph(_skill_graph, {})
		_skill_graph.set_loading(false)


func _flush_active_card() -> void:
	if _loading or _active_deck == null or _active_card_index < 0:
		return
	_persist_active_card()


func _persist_active_card() -> void:
	if _active_deck == null or _active_card_index < 0:
		return
	var card := _active_deck.cards[_active_card_index]
	card.skill_graph = SkillGraphSerializer.serialize_graph(_skill_graph)
	if DeckDataStore.save_deck(_active_deck, _active_deck_path) != OK:
		return
	if _files_panel:
		_files_panel.refresh_card_item(_active_deck_path, _active_card_index)


func _on_card_changed(_card: CardData) -> void:
	if not _loading:
		_persist_active_card()


func _on_skill_graph_changed() -> void:
	if not _loading and _active_deck != null:
		_persist_active_card()
