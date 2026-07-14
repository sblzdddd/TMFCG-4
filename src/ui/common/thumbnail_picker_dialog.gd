@tool
extends Window
class_name ThumbnailPickerDialog

signal item_selected(payload: Variant)

@export var _search: LineEdit
@export var _item_list: ItemList

var _all_entries: Array[Dictionary] = []


func _ready() -> void:
	close_requested.connect(hide)
	if _search:
		_search.text_changed.connect(_on_search_changed)
		_search.gui_input.connect(_on_search_gui_input)
	_item_list.icon_mode = ItemList.ICON_MODE_TOP
	_item_list.max_text_lines = 2
	_item_list.item_activated.connect(_on_item_activated)

	self.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	_on_picker_ready()
	_refresh_list()


func popup_picker() -> void:
	if _search:
		_search.text = ""
	_refresh_list()
	popup_centered_ratio(0.6)
	call_deferred("_focus_picker")


func _focus_picker() -> void:
	if _search:
		_search.grab_focus()
		_search.caret_column = _search.text.length()
	elif _item_list and _item_list.item_count > 0:
		_item_list.grab_focus()
		_item_list.select(0)


## Override for subclass setup (ensure dirs, etc.) before first refresh.
func _on_picker_ready() -> void:
	pass


## Override: return picker entries.
func _collect_entries() -> Array[Dictionary]:
	return []


## Override: validate payload before emitting selection.
func _is_payload_allowed(_payload: Variant) -> bool:
	return true


func _refresh_list() -> void:
	_all_entries = _collect_entries()
	_all_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_name: String = a.get("display_name", a.get("filter_text", ""))
		var b_name: String = b.get("display_name", b.get("filter_text", ""))
		return a_name < b_name
	)
	var query := _search.text.strip_edges() if _search else ""
	_apply_filter(query)


func _apply_filter(query: String) -> void:
	_item_list.clear()
	var normalized_query := query.to_lower()

	for entry: Dictionary in _all_entries:
		if not normalized_query.is_empty():
			var filter_text: String = entry.get("filter_text", entry.get("display_name", ""))
			if not filter_text.to_lower().contains(normalized_query):
				continue

		var index := _item_list.add_item(entry.get("display_name", ""))
		_item_list.set_item_metadata(index, entry.get("payload"))
		var icon: Texture2D = entry.get("icon")
		if icon != null:
			_item_list.set_item_icon(index, icon)


func _on_search_changed(text: String) -> void:
	_apply_filter(text.strip_edges())


func _on_search_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_DOWN:
			if _item_list.item_count > 0:
				_item_list.grab_focus()
				_item_list.select(0)
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _item_list.item_count > 0:
				var index := (
					_item_list.get_selected_items()[0]
					if _item_list.is_anything_selected()
					else 0
				)
				_select_payload(_item_list.get_item_metadata(index))
				get_viewport().set_input_as_handled()


func _on_item_activated(index: int) -> void:
	_select_payload(_item_list.get_item_metadata(index))


func _select_payload(payload: Variant) -> void:
	if payload == null:
		return
	if not _is_payload_allowed(payload):
		return
	_emit_selection(payload)
	hide()


## Override to emit typed selection signals in subclasses.
func _emit_selection(payload: Variant) -> void:
	item_selected.emit(payload)
