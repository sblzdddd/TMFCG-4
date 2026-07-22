class_name CardArray
extends Container
## Procedural H/V card list using CardArranger + CardPose.

@export var horizontal: bool = true
## Step between card origins (gap only — not the visual card size).
@export var slot_size: Vector2 = Vector2(54.0, 54.0)
## When true, use [member stack_gap] as the step so cards overlap.
@export var stack: bool = false
@export var stack_gap: float = 2.0

var _ids: Array[String] = []
var _views: Dictionary = {} # String -> Control
var _anim_index := 0
var _flying: Dictionary = {} # String -> true
var _layout_tweens: Dictionary = {} # String -> Tween


func _ready() -> void:
	if offset_transform_enabled:
		offset_transform_visual_only = false
	for child in get_children():
		child.queue_free()
	_ids.clear()
	_views.clear()
	_layout_tweens.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_apply_positions(false)


func has_card(instance_id: String) -> bool:
	return _views.has(instance_id)


func get_card_view(instance_id: String) -> Control:
	return _views.get(instance_id) as Control


func get_ordered_ids() -> Array[String]:
	return _ids.duplicate()


func capture_pose(instance_id: String) -> Dictionary:
	var view := get_card_view(instance_id)
	return {} if view == null else CardPose.capture(view)


func next_stagger_delay() -> float:
	var d := float(_anim_index) * CardAnim.stagger_delay()
	_anim_index += 1
	return d


func reset_stagger() -> void:
	_anim_index = 0


func gap_step() -> float:
	if stack:
		return stack_gap
	return slot_size.x if horizontal else slot_size.y


func remove_card(instance_id: String, to_nowhere: bool = false, delay: float = 0.0) -> Dictionary:
	var view := get_card_view(instance_id)
	if view == null:
		return {}
	var pose := CardPose.capture(view)
	_ids.erase(instance_id)
	_views.erase(instance_id)
	_flying.erase(instance_id)
	_kill_layout_tween(instance_id)
	# Bulk discards (round-end GY flush) must not serialize long fades.
	if to_nowhere:
		_fade_free(view, CardAnim.fade_out_duration())
		_layout(true)
		return pose
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(view):
		return pose
	if view.get_parent() != null:
		view.get_parent().remove_child(view)
	view.queue_free()
	_layout(true)
	return pose


func _fade_free(view: Control, duration: float) -> void:
	if not is_instance_valid(view):
		return
	# Fade in place. Avoid top_level: leftover position tweens + parent
	# offset_transform rebase local slot coords into viewport space (fly left).
	var dim := Color(modulate.r, modulate.g, modulate.b, view.modulate.a)
	view.z_index = CardPose.FLY_Z_INDEX
	view.modulate = dim
	var tw := CardAnim.init_fade_out_tween(view)
	tw.tween_property(view, "modulate:a", 0.0, duration)
	tw.tween_callback(
		func() -> void:
			if is_instance_valid(view):
				view.queue_free()
	)


func _kill_layout_tween(instance_id: String) -> void:
	if not _layout_tweens.has(instance_id):
		return
	var tw: Tween = _layout_tweens[instance_id]
	_layout_tweens.erase(instance_id)
	if tw != null and is_instance_valid(tw):
		tw.kill()


func add_card(
	card: Card, from_pose: Dictionary = {}, delay: float = 0.0, _i: int = -1, face_up: bool = true
) -> Control:
	var id := card.instance_id.value
	if _views.has(id):
		return _refresh(id, card, face_up)
	var view := CardViewFactory.make_base(card, true) if face_up else CardViewFactory.make_back(id)
	_insert(id, view, from_pose, delay)
	return view


func add_flippable_card(
	card: Card, from_pose: Dictionary = {}, delay: float = 0.0, _i: int = -1
) -> CardBase:
	var id := card.instance_id.value
	if _views.has(id):
		var existing := _views[id] as CardBase
		CardViewFactory.apply_data(existing, card)
		existing.set_face_up(false, false)
		return existing
	var base := CardViewFactory.make_base(card, false)
	_insert(id, base, from_pose, delay)
	return base


func _insert(id: String, view: Control, from_pose: Dictionary, delay: float) -> void:
	_ids.append(id)
	_views[id] = view
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.custom_minimum_size = slot_size
	view.size = slot_size
	var will_fly := not from_pose.is_empty()
	if will_fly or delay > 0.0:
		_flying[id] = true
	add_child(view)
	# Defer fly so Container sort + transforms settle (fixes single-card teleport).
	_start_enter(id, view, from_pose, delay, will_fly)


func _start_enter(
	id: String, view: Control, from_pose: Dictionary, delay: float, will_fly: bool
) -> void:
	# Pin at origin before any layout so the card never flashes at slot (0,0).
	if will_fly:
		_flying[id] = true
		CardPose.apply_start(view, from_pose)
		view.modulate.a = 1.0
	else:
		_layout(true)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	else:
		await get_tree().process_frame
	if not is_instance_valid(view) or not _views.has(id):
		return
	await _animate_in(id, view, from_pose)


func _animate_in(id: String, view: Control, from_pose: Dictionary) -> void:
	if from_pose.is_empty():
		_flying.erase(id)
		view.modulate.a = 1.0
		view.position = _slot_pos(id)
		_layout(true)
		return
	_flying[id] = true
	CardPose.apply_start(view, from_pose)
	view.modulate.a = 1.0
	await get_tree().process_frame
	if not is_instance_valid(view) or not _views.has(id):
		return
	var local := _slot_pos(id)
	# Dest size for settled origin; start still uses captured source size from apply_start.
	var saved := view.size
	view.custom_minimum_size = slot_size
	view.size = slot_size
	var dest := CardPose.settled_global_position(self, view, local)
	view.custom_minimum_size = saved
	view.size = saved
	view.global_position = from_pose.get("global_position", view.global_position)
	await CardPose.fly_to(view, dest, CardPose.settle_fly_scale(self), slot_size, -1.0, from_pose)
	if is_instance_valid(view) and _views.has(id):
		_flying.erase(id)
		CardPose.settle(view, self, local, slot_size)
		queue_sort()


func _targets() -> Array[Vector2]:
	return CardArranger.targets(
		Rect2(Vector2.ZERO, size), _ids.size(), gap_step(), horizontal, slot_size
	)


func _layout(animate: bool) -> void:
	_apply_positions(animate)


func _apply_positions(animate: bool) -> void:
	var targets := _targets()
	for i in _ids.size():
		var id := _ids[i]
		var view := _views[id] as Control
		if _flying.has(id) or not is_instance_valid(view) or view.top_level:
			continue
		view.size = slot_size
		if animate:
			var tw := CardAnim.init_tween(view, _layout_tweens.get(id) as Tween)
			_layout_tweens[id] = tw
			tw.tween_property(view, "position", targets[i], CardAnim.move_duration())
		else:
			_kill_layout_tween(id)
			view.position = targets[i]


func _slot_pos(id: String) -> Vector2:
	var idx := _ids.find(id)
	var targets := _targets()
	return targets[idx] if idx >= 0 and idx < targets.size() else Vector2.ZERO


func _refresh(id: String, card: Card, face_up: bool) -> Control:
	var existing := _views[id] as Control
	if face_up and existing is CardBase:
		CardViewFactory.apply_data(existing as CardBase, card)
		(existing as CardBase).set_face_up(true, false)
		return existing
	var neu := CardViewFactory.make_base(card, true) if face_up else CardViewFactory.make_back(id)
	var old := existing
	_views[id] = neu
	var idx := old.get_index()
	var pos := old.position
	old.queue_free()
	neu.custom_minimum_size = slot_size
	neu.size = slot_size
	add_child(neu)
	move_child(neu, idx)
	neu.position = pos
	return neu
