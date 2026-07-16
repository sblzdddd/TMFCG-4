class_name UiCardList
extends ScrollContainer
## Vertical UI card list that refreshes without clearing selection by id.

signal item_selected(id: String)
signal item_activated(id: String)
signal action_pressed(id: String, action_id: String)

const _UiCardItemScene := preload("res://definitions/prefabs/pre_ui_card_item.tscn")

@onready var _items_box: VBoxContainer = %Items

var selected_id: String = ""
var _items: Dictionary[String, UiCardItem] = {}


func clear_items() -> void:
	selected_id = ""
	_items.clear()
	if _items_box == null:
		return
	for child in _items_box.get_children():
		child.queue_free()


func set_items(entries: Array[UiCardEntry]) -> void:
	if not is_node_ready():
		call_deferred("set_items", entries)
		return
	var keep_id := selected_id
	var existing_ids: Dictionary[String, bool] = {}
	for entry: UiCardEntry in entries:
		if entry == null or entry.id.is_empty():
			continue
		existing_ids[entry.id] = true

	# Remove stale rows.
	var remove_ids: Array[String] = []
	for id: String in _items.keys():
		if not existing_ids.has(id):
			remove_ids.append(id)
	for id: String in remove_ids:
		var row: UiCardItem = _items[id]
		_items.erase(id)
		if is_instance_valid(row):
			row.queue_free()

	# Upsert in order.
	var index := 0
	for entry: UiCardEntry in entries:
		if entry == null or entry.id.is_empty():
			continue
		var row: UiCardItem = _items.get(entry.id) as UiCardItem
		if row == null or not is_instance_valid(row):
			row = _UiCardItemScene.instantiate() as UiCardItem
			_items_box.add_child(row)
			_items[entry.id] = row
			row.selected.connect(_on_item_selected)
			row.activated.connect(_on_item_activated)
			row.action_pressed.connect(_on_item_action)
		_items_box.move_child(row, index)
		row.configure(entry)
		index += 1

	if keep_id.is_empty() or not _items.has(keep_id):
		selected_id = ""
	else:
		selected_id = keep_id
	_apply_selection_visuals()


func select_id(id: String) -> void:
	if id.is_empty() or not _items.has(id):
		selected_id = ""
	else:
		selected_id = id
	_apply_selection_visuals()
	if not selected_id.is_empty():
		item_selected.emit(selected_id)


func get_selected_id() -> String:
	return selected_id


func _on_item_selected(id: String) -> void:
	select_id(id)


func _on_item_activated(id: String) -> void:
	select_id(id)
	item_activated.emit(id)


func _on_item_action(id: String, action_id: String) -> void:
	action_pressed.emit(id, action_id)


func _apply_selection_visuals() -> void:
	for id in _items:
		var row: UiCardItem = _items[id]
		if is_instance_valid(row):
			row.selected_state = (id == selected_id)
