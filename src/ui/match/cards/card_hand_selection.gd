class_name CardHandSelection
extends RefCounted
## Click / drag multi-select for an active CardArray of CardBase views.

signal selection_changed

var _array: CardArray
var _selected: Dictionary = {} # instance_id -> true
var _dragging := false
var _paint_select := true
var _bound: Dictionary = {} # instance_id -> CardBase
## Touch gesture: armed on touch_started; paints via touch_dragged hit-tests; tap on touch_ended.
var _touch_armed := false
var _touch_dragged := false
var _touch_origin_id := ""


func bind(array: CardArray) -> void:
	_array = array


func clear() -> void:
	for id in _selected.keys():
		var base := _get_bound(str(id))
		if base != null:
			base.selected = false
	_selected.clear()
	_clear_touch_gesture()
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
	if not base.touch_started.is_connected(_on_touch_started):
		base.touch_started.connect(_on_touch_started)
	if not base.touch_dragged.is_connected(_on_touch_dragged):
		base.touch_dragged.connect(_on_touch_dragged)
	if not base.touch_ended.is_connected(_on_touch_ended):
		base.touch_ended.connect(_on_touch_ended)


func _unbind(id: String) -> void:
	var base := _get_bound(id)
	_bound.erase(id)
	if base == null:
		return
	if base.pressed.is_connected(_on_pressed):
		base.pressed.disconnect(_on_pressed)
	if base.hovered.is_connected(_on_hovered):
		base.hovered.disconnect(_on_hovered)
	if base.touch_started.is_connected(_on_touch_started):
		base.touch_started.disconnect(_on_touch_started)
	if base.touch_dragged.is_connected(_on_touch_dragged):
		base.touch_dragged.disconnect(_on_touch_dragged)
	if base.touch_ended.is_connected(_on_touch_ended):
		base.touch_ended.disconnect(_on_touch_ended)
	base.interactable = false
	base.info_hover_delay = 0.0
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.refresh_interaction()
	base.selected = false


func _enable(base: CardBase) -> void:
	base.interactable = true
	base.info_hover_delay = CardBase.ACTIVE_HAND_INFO_HOVER_DELAY
	# Hits go through CardVisual only (sized to the offset-transform visual).
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.refresh_interaction()


func _id_of(base: CardBase) -> String:
	if not is_instance_valid(base):
		return ""
	return str(base.get_meta(CardViewFactory.META_INSTANCE_ID, ""))


func _on_touch_started(card: CardBase) -> void:
	var id := _id_of(card)
	if id.is_empty():
		return
	_touch_armed = true
	_touch_dragged = false
	_touch_origin_id = id
	_dragging = true
	_paint_select = not _selected.has(id)


func _on_touch_dragged(_origin: CardBase, global_pos: Vector2) -> void:
	if not _touch_armed:
		return
	var hit := _topmost_card_at(global_pos)
	if hit == null:
		return
	var id := _id_of(hit)
	if id.is_empty() or id == _touch_origin_id:
		return
	if not _touch_dragged:
		_touch_dragged = true
		var origin := _get_bound(_touch_origin_id)
		if origin != null:
			origin.mark_touch_moved()
			_apply(_touch_origin_id, origin, _paint_select)
	_apply(id, hit, _paint_select)


func _on_touch_ended(_card: CardBase, as_tap: bool) -> void:
	if not _touch_armed:
		return
	if _touch_dragged:
		# Cards already painted while the finger moved across the hand.
		_clear_touch_gesture()
		return
	if as_tap:
		var origin := _get_bound(_touch_origin_id)
		if origin != null:
			_apply(_touch_origin_id, origin, _paint_select)
	_clear_touch_gesture()


func _on_pressed(card: CardBase, from_touch: bool = false) -> void:
	# Touch taps are committed in _on_touch_ended (avoids double-apply with drag).
	if from_touch:
		return
	var id := _id_of(card)
	if id.is_empty():
		return
	var select := not _selected.has(id)
	_dragging = true
	_paint_select = select
	_apply(id, card, _paint_select)


func _on_hovered(card: CardBase) -> void:
	# Mouse drag paint only — touch uses touch_dragged hit-tests (emulated mouse is captured).
	if not _dragging or _touch_armed:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		return
	var id := _id_of(card)
	if id.is_empty():
		return
	_apply(id, card, _paint_select)


## Topmost interactable card under [param global_pos] (later hand order draws above).
func _topmost_card_at(global_pos: Vector2) -> CardBase:
	if _array == null:
		return null
	var ids := _array.get_ordered_ids()
	for i in range(ids.size() - 1, -1, -1):
		var id := str(ids[i])
		var base := _get_bound(id)
		if base == null or not base.interactable or base.visual == null:
			continue
		if base.visual.get_global_rect().has_point(global_pos):
			return base
	return null


func _clear_touch_gesture() -> void:
	_touch_armed = false
	_touch_dragged = false
	_touch_origin_id = ""
	_dragging = false


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
