extends Window
class_name ThumbnailPickerDialog

signal item_selected(payload: Variant)

## Finger travel (px²) before a press counts as a scroll drag, not a tap.
const _TAP_MOVE_THRESHOLD_SQ := 64.0

@export var _search: LineEdit
@export var _item_list: ItemList

var _all_entries: Array[Dictionary] = []
var _scroll: ScrollContainer
var _pending_tap_index := -1
var _press_global_pos := Vector2.ZERO
var _press_scroll_offset := Vector2.ZERO


func _ready() -> void:
	close_requested.connect(hide)
	visibility_changed.connect(_on_visibility_changed)
	if _search:
		_search.text_changed.connect(_on_search_changed)
		_search.gui_input.connect(_on_search_gui_input)
	_item_list.icon_mode = ItemList.ICON_MODE_TOP
	_item_list.max_text_lines = 2
	# Size to content and pass drag to parent ScrollContainer (touch / emulate mouse).
	_item_list.auto_height = true
	_item_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_item_list.item_activated.connect(_on_item_activated)
	_scroll = _item_list.get_parent() as ScrollContainer
	if PlatformUtils.is_mobile():
		# item_clicked fires on press; defer activation until release so scroll can win.
		_item_list.item_clicked.connect(_on_item_pressed_mobile)

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
	_cancel_pending_tap()
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


func _on_item_pressed_mobile(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	_pending_tap_index = index
	_press_global_pos = _item_list.get_global_mouse_position()
	_press_scroll_offset = _current_scroll_offset()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _pending_tap_index < 0:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _tap_became_drag():
			_cancel_pending_tap()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		_finish_pending_tap()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		# Emulated touch from mouse — MouseButton path owns the gesture.
		if st.pressed or st.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_finish_pending_tap()


func _current_scroll_offset() -> Vector2:
	if _scroll == null:
		return Vector2.ZERO
	return Vector2(float(_scroll.scroll_horizontal), float(_scroll.scroll_vertical))


func _tap_became_drag() -> bool:
	if _current_scroll_offset().distance_squared_to(_press_scroll_offset) > 0.25:
		return true
	return (
		_item_list.get_global_mouse_position().distance_squared_to(_press_global_pos)
		>= _TAP_MOVE_THRESHOLD_SQ
	)


func _cancel_pending_tap() -> void:
	_pending_tap_index = -1
	set_process_input(false)


func _finish_pending_tap() -> void:
	var index := _pending_tap_index
	var dragged := _tap_became_drag()
	_cancel_pending_tap()
	if dragged or index < 0 or index >= _item_list.item_count:
		return
	_on_item_activated(index)


func _on_visibility_changed() -> void:
	if not visible:
		_cancel_pending_tap()


func _select_payload(payload: Variant) -> void:
	if payload == null:
		return
	if not _is_payload_allowed(payload):
		return
	_cancel_pending_tap()
	_emit_selection(payload)
	hide()


## Override to emit typed selection signals in subclasses.
func _emit_selection(payload: Variant) -> void:
	item_selected.emit(payload)
