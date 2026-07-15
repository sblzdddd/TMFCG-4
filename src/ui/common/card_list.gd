class_name CardList
extends ScrollContainer
## Vertical card list that refreshes without clearing selection by id.

signal item_selected(id: String)
signal item_activated(id: String)
signal action_pressed(id: String, action_id: String)

const _CardItemScene := preload("res://definitions/prefabs/pre_card_item.tscn")

@onready var _items_box: VBoxContainer = %Items

var selected_id: String = ""
var _cards: Dictionary[String, CardItem] = {}


func clear_items() -> void:
	selected_id = ""
	_cards.clear()
	if _items_box == null:
		return
	for child in _items_box.get_children():
		child.queue_free()


## items: Array of {id, title, subtitle?, action_text?, action_id?, icon?}
func set_items(items: Array[Dictionary]) -> void:
	if not is_node_ready():
		call_deferred("set_items", items)
		return
	var keep_id := selected_id
	var existing_ids: Dictionary[String, bool] = {}
	for entry: Dictionary in items:
		existing_ids[str(entry.get("id", ""))] = true

	# Remove stale cards.
	var remove_ids: Array[String] = []
	for id: String in _cards.keys():
		if not existing_ids.has(id):
			remove_ids.append(id)
	for id: String in remove_ids:
		var card: CardItem = _cards[id]
		_cards.erase(id)
		if is_instance_valid(card):
			card.queue_free()

	# Upsert in order.
	var index := 0
	for entry: Dictionary in items:
		var id := str(entry.get("id", ""))
		if id.is_empty():
			continue
		var card: CardItem = _cards.get(id) as CardItem
		if card == null or not is_instance_valid(card):
			card = _CardItemScene.instantiate() as CardItem
			_items_box.add_child(card)
			_cards[id] = card
			card.selected.connect(_on_card_selected)
			card.activated.connect(_on_card_activated)
			card.action_pressed.connect(_on_card_action)
		_items_box.move_child(card, index)
		card.configure(
			id,
			str(entry.get("title", "")),
			str(entry.get("subtitle", "")),
			str(entry.get("action_text", "")),
			str(entry.get("action_id", "")),
			entry.get("icon") as Texture2D,
		)
		index += 1

	if keep_id.is_empty() or not _cards.has(keep_id):
		selected_id = ""
	else:
		selected_id = keep_id
	_apply_selection_visuals()


func select_id(id: String) -> void:
	if id.is_empty() or not _cards.has(id):
		selected_id = ""
	else:
		selected_id = id
	_apply_selection_visuals()
	if not selected_id.is_empty():
		item_selected.emit(selected_id)


func get_selected_id() -> String:
	return selected_id


func _on_card_selected(id: String) -> void:
	select_id(id)


func _on_card_activated(id: String) -> void:
	select_id(id)
	item_activated.emit(id)


func _on_card_action(id: String, action_id: String) -> void:
	action_pressed.emit(id, action_id)


func _apply_selection_visuals() -> void:
	for id in _cards:
		var card: CardItem = _cards[id]
		if is_instance_valid(card):
			card.selected_state = (id == selected_id)
