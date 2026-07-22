class_name CardHandSelection
extends RefCounted
## Click / drag multi-select for an active CardArray of CardBase views.

signal selection_changed

var _array: CardArray
var _selected: Dictionary = {} # instance_id -> true
var _dragging := false
var _paint_select := true
var _bound: Dictionary = {} # instance_id -> CardBase


func bind(array: CardArray) -> void:
	_array = array


func clear() -> void:
	for id in _selected.keys():
		var base := _get_bound(str(id))
		if base != null:
			base.selected = false
	_selected.clear()
	selection_changed.emit()


func get_selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _selected.keys():
		ids.append(str(id))
	return ids


func refresh() -> void:
	if _array == null:
		return
	var alive: Dictionary = {}
	for id in _array.get_ordered_ids():
		alive[id] = true
		var view := _array.get_card_view(id)
		if view is CardBase:
			_ensure_bound(id, view as CardBase)
	for id in _bound.keys():
		if not alive.has(id):
			_unbind(str(id))
	var pruned := false
	for id in _selected.keys():
		if not alive.has(id):
			_selected.erase(id)
			pruned = true
	if pruned:
		selection_changed.emit()


func _get_bound(id: String) -> CardBase:
	if not _bound.has(id):
		return null
	var obj: Variant = _bound[id]
	if typeof(obj) != TYPE_OBJECT or not is_instance_valid(obj):
		_bound.erase(id)
		return null
	return obj as CardBase


func _ensure_bound(id: String, base: CardBase) -> void:
	var existing := _get_bound(id)
	if existing == base:
		_enable(base)
		base.selected = _selected.has(id)
		return
	_unbind(id)
	_bound[id] = base
	_enable(base)
	base.selected = _selected.has(id)
	if not base.pressed.is_connected(_on_pressed):
		base.pressed.connect(_on_pressed)
	if not base.hovered.is_connected(_on_hovered):
		base.hovered.connect(_on_hovered)


func _unbind(id: String) -> void:
	var base := _get_bound(id)
	_bound.erase(id)
	if base == null:
		return
	if base.pressed.is_connected(_on_pressed):
		base.pressed.disconnect(_on_pressed)
	if base.hovered.is_connected(_on_hovered):
		base.hovered.disconnect(_on_hovered)
	base.interactable = false
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.selected = false


func _enable(base: CardBase) -> void:
	base.interactable = true
	base.mouse_filter = Control.MOUSE_FILTER_STOP
	if base.visual != null:
		base.visual.mouse_filter = Control.MOUSE_FILTER_STOP


func _id_of(base: CardBase) -> String:
	if not is_instance_valid(base):
		return ""
	return str(base.get_meta(CardViewFactory.META_INSTANCE_ID, ""))


func _on_pressed(card: CardBase) -> void:
	var id := _id_of(card)
	if id.is_empty():
		return
	_dragging = true
	_paint_select = not _selected.has(id)
	_apply(id, card, _paint_select)


func _on_hovered(card: CardBase) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		return
	if not _dragging:
		return
	var id := _id_of(card)
	if id.is_empty():
		return
	_apply(id, card, _paint_select)


func _apply(id: String, base: CardBase, select: bool) -> void:
	if select == _selected.has(id):
		return
	if select:
		_selected[id] = true
	else:
		_selected.erase(id)
	if is_instance_valid(base):
		base.selected = select
	selection_changed.emit()
