@tool
extends Tree
class_name DeckFileTree

const FileTreeLayout := preload("res://src/editor/filetree/file_tree_layout.gd")

signal resource_selected(metadata: Dictionary)
signal add_card_requested(deck_path: String)

const ADD_CARD_BUTTON_ID := 0

@export var folder_icon: Texture2D
@export var deck_icon: Texture2D
@export var add_card_icon: Texture2D
@export var club_icon: Texture2D
@export var diamond_icon: Texture2D
@export var heart_icon: Texture2D
@export var spade_icon: Texture2D

var show_builtin := true
var _section_root: TreeItem = null
var _card_items_by_key: Dictionary = {}


func _ready() -> void:
	FileTreeLayout.prepare(self)
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)
	if not button_clicked.is_connected(_on_button_clicked):
		button_clicked.connect(_on_button_clicked)
	if not item_collapsed.is_connected(_on_item_collapsed):
		item_collapsed.connect(_on_item_collapsed)
	refresh()


func refresh() -> void:
	clear()
	_card_items_by_key.clear()
	_section_root = create_item()
	_section_root.set_text(0, "牌组")
	_section_root.set_selectable(0, false)
	if folder_icon:
		_section_root.set_icon(0, folder_icon)
	for path in DeckDataStore.list_paths(show_builtin):
		_add_deck_item(DeckDataStore.load_deck(path), path)
	call_deferred("_fit_content_height")


func refresh_card_item(deck_path: String, card_index: int) -> void:
	var item: TreeItem = _card_items_by_key.get(_card_key(deck_path, card_index))
	if item == null:
		return
	var deck := DeckDataStore.load_deck(deck_path)
	if deck == null or card_index < 0 or card_index >= deck.cards.size():
		return
	_apply_card_item(item, deck.cards[card_index], card_index, deck_path)


func refresh_deck_cards(deck_path: String) -> void:
	var deck_item := _find_deck_item(deck_path)
	if deck_item == null:
		refresh()
		return
	var deck := DeckDataStore.load_deck(deck_path)
	if deck == null:
		return
	var child := deck_item.get_first_child()
	while child:
		var next := child.get_next()
		var meta: Dictionary = child.get_metadata(0)
		_card_items_by_key.erase(_card_key(deck_path, meta.get("card_index", -1)))
		child.free()
		child = next
	for i in range(deck.cards.size()):
		_add_card_item(deck_item, deck.cards[i], i, deck_path)
	call_deferred("_fit_content_height")


func select_card(deck_path: String, card_index: int) -> void:
	var item: TreeItem = _card_items_by_key.get(_card_key(deck_path, card_index))
	if item == null:
		return
	item.select(0)
	scroll_to_item(item)


func get_selected_metadata() -> Dictionary:
	var item := get_selected()
	return {} if item == null else item.get_metadata(0)


func _add_deck_item(deck: DeckData, path: String) -> void:
	if deck == null:
		return
	var builtin := ResourceFsUtils.is_builtin_path(path)
	var item := create_item(_section_root)
	item.set_text(0, deck.name if not deck.name.is_empty() else path.get_file().get_basename())
	item.set_metadata(0, {"type": "deck", "path": path, "builtin": builtin})
	item.set_icon(0, deck_icon)
	if add_card_icon:
		item.add_button(0, add_card_icon, ADD_CARD_BUTTON_ID, false, "添加卡牌")
	for i in range(deck.cards.size()):
		_add_card_item(item, deck.cards[i], i, path)


func _add_card_item(parent: TreeItem, card: CardData, index: int, deck_path: String) -> void:
	if card == null:
		return
	_apply_card_item(create_item(parent), card, index, deck_path)


func _apply_card_item(item: TreeItem, card: CardData, index: int, deck_path: String) -> void:
	item.set_text(0, CardUtils.card_tree_label(card))
	item.set_icon(0, _suit_icon(card.suit))
	item.set_metadata(0, {
		"type": "card", "path": deck_path, "card_index": index,
		"builtin": ResourceFsUtils.is_builtin_path(deck_path),
	})
	_card_items_by_key[_card_key(deck_path, index)] = item


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
	var child := _section_root.get_first_child() if _section_root else null
	while child:
		var meta: Dictionary = child.get_metadata(0)
		if meta.get("type") == "deck" and meta.get("path") == deck_path:
			return child
		child = child.get_next()
	return null


func _on_item_selected() -> void:
	var item := get_selected()
	resource_selected.emit({} if item == null else item.get_metadata(0))


func _on_button_clicked(item: TreeItem, _c: int, id: int, _m: int) -> void:
	if id != ADD_CARD_BUTTON_ID:
		return
	var meta: Dictionary = item.get_metadata(0)
	if meta.get("type") == "deck":
		add_card_requested.emit(meta.get("path", ""))


func _on_item_collapsed(_item: TreeItem) -> void:
	call_deferred("_fit_content_height")


func _fit_content_height() -> void:
	FileTreeLayout.fit_height(self)
