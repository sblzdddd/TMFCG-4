@tool
extends Tree
class_name EditorFileTree

signal resource_selected(metadata: Dictionary)
signal add_card_requested(deck_path: String)

const ADD_CARD_BUTTON_ID := 0

@export var folder_icon: Texture2D
@export var deck_icon: Texture2D
@export var character_icon: Texture2D
@export var add_card_icon: Texture2D
@export var club_icon: Texture2D
@export var diamond_icon: Texture2D
@export var heart_icon: Texture2D
@export var spade_icon: Texture2D

var _root: TreeItem = null
var _deck_root: TreeItem = null
var _character_list_root: TreeItem = null
var _card_items_by_key: Dictionary = {}
var show_builtin_characters := true
var show_builtin_decks := true


func create_folder(folder_name: String, parent: TreeItem) -> TreeItem:
	var folder = create_item(parent)
	folder.set_icon(0, folder_icon)
	folder.set_text(0, folder_name)
	return folder


func init_roots() -> void:
	if _root != null or _deck_root != null or _character_list_root != null:
		return
	_root = create_item()
	hide_root = true
	_deck_root = create_folder("牌组", _root)
	_character_list_root = create_folder("角色", _root)


func _ready() -> void:
	ResourceFsUtils.ensure_directories()
	init_roots()
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)
	if not button_clicked.is_connected(_on_button_clicked):
		button_clicked.connect(_on_button_clicked)
	refresh()


func refresh() -> void:
	init_roots()
	_clear_children(_deck_root)
	_clear_children(_character_list_root)
	_card_items_by_key.clear()
	hide_root = true

	if show_builtin_decks:
		for path in ResourceFsUtils.list_files(ResConst.PRESET_DECKS_DIR, "tres"):
			add_deck_item(load(path) as DeckData, path)
	for path in ResourceFsUtils.list_files(ResConst.USER_DECKS_DIR, "tres"):
		add_deck_item(load(path) as DeckData, path)

	if show_builtin_characters:
		for path in ResourceFsUtils.list_files(ResConst.PRESET_CHARACTERS_DIR, "dch"):
			add_character_item(load(path) as DialogicCharacter, path)
	for path in ResourceFsUtils.list_files(ResConst.USER_CHARACTERS_DIR, "dch"):
		add_character_item(load(path) as DialogicCharacter, path)


func add_deck_item(deck: DeckData, path: String) -> TreeItem:
	if deck == null:
		return null
	if path.begins_with(ResConst.PRESET_DECKS_DIR) and not show_builtin_decks:
		return null

	var builtin := ResourceFsUtils.is_builtin_path(path)
	var item := create_item(_deck_root)
	item.set_text(0, deck.name if not deck.name.is_empty() else path.get_file().get_basename())
	item.set_metadata(0, {"type": "deck", "path": path, "builtin": builtin})
	item.set_icon(0, deck_icon)
	if add_card_icon:
		item.add_button(0, add_card_icon, ADD_CARD_BUTTON_ID, false, "添加卡牌")

	for card_index in range(deck.cards.size()):
		add_card_item(item, deck.cards[card_index], card_index, path, builtin)

	return item


func add_card_item(
	parent: TreeItem,
	card: CardData,
	card_index: int,
	deck_path: String,
	builtin: bool
) -> TreeItem:
	if card == null:
		return null

	var item := create_item(parent)
	_apply_card_item(item, card, card_index, deck_path, builtin)
	return item


func refresh_card_item(deck_path: String, card_index: int) -> void:
	var key := _card_key(deck_path, card_index)
	var item: TreeItem = _card_items_by_key.get(key)
	if item == null:
		return
	var deck := load(deck_path) as DeckData
	if deck == null or card_index < 0 or card_index >= deck.cards.size():
		return
	var builtin := ResourceFsUtils.is_builtin_path(deck_path)
	_apply_card_item(item, deck.cards[card_index], card_index, deck_path, builtin)


func refresh_deck_cards(deck_path: String) -> void:
	var deck_item := _find_deck_item(deck_path)
	if deck_item == null:
		refresh()
		return

	var deck := load(deck_path) as DeckData
	if deck == null:
		return

	var builtin := ResourceFsUtils.is_builtin_path(deck_path)
	var child := deck_item.get_first_child()
	while child:
		var next := child.get_next()
		var metadata: Dictionary = child.get_metadata(0)
		var key: String = _card_key(deck_path, metadata.get("card_index", -1))
		_card_items_by_key.erase(key)
		child.free()
		child = next

	for card_index in range(deck.cards.size()):
		add_card_item(deck_item, deck.cards[card_index], card_index, deck_path, builtin)


func select_card(deck_path: String, card_index: int) -> void:
	var key := _card_key(deck_path, card_index)
	var item: TreeItem = _card_items_by_key.get(key)
	if item == null:
		return
	item.select(0)
	scroll_to_item(item)


func get_selected_metadata() -> Dictionary:
	var item := get_selected()
	if item == null:
		return {}
	return item.get_metadata(0)


func add_character_item(character: DialogicCharacter, path: String) -> TreeItem:
	if character == null:
		return null
	if path.begins_with(ResConst.PRESET_CHARACTERS_DIR) and not show_builtin_characters:
		return null

	var label := character.display_name
	if label.is_empty():
		label = path.get_file().get_basename()

	var item := create_item(_character_list_root)
	item.set_text(0, label)
	item.set_metadata(0, {
		"type": "character",
		"path": path,
		"builtin": ResourceFsUtils.is_builtin_path(path),
	})
	item.set_icon(0, character_icon)
	return item


func _apply_card_item(
	item: TreeItem,
	card: CardData,
	card_index: int,
	deck_path: String,
	builtin: bool
) -> void:
	item.set_text(0, CardUtils.card_tree_label(card))
	item.set_icon(0, _suit_icon(card.suit))
	item.set_metadata(0, {
		"type": "card",
		"path": deck_path,
		"card_index": card_index,
		"builtin": builtin,
	})
	var key := _card_key(deck_path, card_index)
	_card_items_by_key[key] = item


func _suit_icon(suit: CardEnums.Suit) -> Texture2D:
	match suit:
		CardEnums.Suit.CLUBS: return club_icon
		CardEnums.Suit.DIAMONDS: return diamond_icon
		CardEnums.Suit.HEARTS: return heart_icon
		CardEnums.Suit.SPADES: return spade_icon
		_: return null


func _card_key(deck_path: String, card_index: int) -> String:
	return "%s:%d" % [deck_path, card_index]


func _find_deck_item(deck_path: String) -> TreeItem:
	var child := _deck_root.get_first_child()
	while child:
		var metadata: Dictionary = child.get_metadata(0)
		if metadata.get("type") == "deck" and metadata.get("path") == deck_path:
			return child
		child = child.get_next()
	return null


func _on_item_selected() -> void:
	var item := get_selected()
	if item == null:
		resource_selected.emit({})
		return
	resource_selected.emit(item.get_metadata(0))


func _on_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	if id != ADD_CARD_BUTTON_ID:
		return
	var metadata: Dictionary = item.get_metadata(0)
	if metadata.get("type") != "deck":
		return
	add_card_requested.emit(metadata.get("path", ""))


func _clear_children(folder: TreeItem) -> void:
	if folder == null:
		return
	var child := folder.get_first_child()
	while child:
		var next := child.get_next()
		child.free()
		child = next
