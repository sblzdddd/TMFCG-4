class_name EmojiPicker
extends PopupPanel
## Textless emoji/sticker picker: category icon tabs + icon ItemList grid.

signal emoji_selected(id: String)

const POPUP_SIZE := Vector2(280, 220)
const EMOJI_ICON_SIZE := Vector2(40, 40)
const CATEGORY_ICON_SIZE := Vector2(36, 36)

@onready var category_bar: HBoxContainer = %CategoryBar
@onready var emoji_list: ItemList = %EmojiList

var _active_category: String = ""
var _category_buttons: Dictionary = {}
## ItemList index -> emoji id
var _list_ids: Array[String] = []


func _ready() -> void:
	emoji_list.max_columns = 5
	emoji_list.same_column_width = true
	emoji_list.icon_mode = ItemList.ICON_MODE_TOP
	emoji_list.fixed_icon_size = EMOJI_ICON_SIZE
	emoji_list.allow_reselect = true
	emoji_list.item_clicked.connect(_on_emoji_item_clicked)
	_build_categories()
	if not EmojiDataStore.categories.is_empty():
		select_category(EmojiDataStore.categories[0])


func _build_categories() -> void:
	for child in category_bar.get_children():
		child.queue_free()
	_category_buttons.clear()
	for category in EmojiDataStore.get_categories():
		var emojis: Array = EmojiDataStore.get_emojis(category)
		if emojis.is_empty():
			continue
		var first: Dictionary = emojis[0] as Dictionary
		var btn := Button.new()
		btn.custom_minimum_size = CATEGORY_ICON_SIZE + Vector2(8, 8)
		btn.icon = first.get("texture") as Texture2D
		btn.expand_icon = true
		btn.flat = true
		btn.tooltip_text = category
		btn.pressed.connect(select_category.bind(category))
		category_bar.add_child(btn)
		_category_buttons[category] = btn


func select_category(category: String) -> void:
	_active_category = category
	emoji_list.clear()
	_list_ids.clear()
	for entry_v in EmojiDataStore.get_emojis(category):
		var entry: Dictionary = entry_v as Dictionary
		var id := str(entry.get("id", ""))
		var tex := entry.get("texture") as Texture2D
		var idx := emoji_list.add_item("", tex)
		emoji_list.set_item_tooltip(idx, str(entry.get("name", id)))
		_list_ids.append(id)
	for cat in _category_buttons:
		var btn: Button = _category_buttons[cat] as Button
		btn.modulate = Color(1, 1, 1, 1.0 if cat == category else 0.45)


func toggle_above(anchor: Control) -> void:
	if visible:
		hide()
		return
	popup_above(anchor)


func toggle_below(anchor: Control) -> void:
	if visible:
		hide()
		return
	popup_below(anchor)


func popup_above(anchor: Control) -> void:
	var rect := anchor.get_global_rect()
	var pos := Vector2(rect.position.x, rect.position.y - POPUP_SIZE.y - 4)
	popup(Rect2i(Vector2i(pos), Vector2i(POPUP_SIZE)))


func popup_below(anchor: Control) -> void:
	var rect := anchor.get_global_rect()
	var pos := Vector2(rect.position.x, rect.end.y + 4)
	popup(Rect2i(Vector2i(pos), Vector2i(POPUP_SIZE)))


func _on_emoji_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if index < 0 or index >= _list_ids.size():
		return
	emoji_selected.emit(_list_ids[index])
	hide()
