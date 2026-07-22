class_name CardPose
extends RefCounted
## Capture / fly / settle helpers for cross-array card motion.

static func capture(view: Control) -> Dictionary:
	return {
		"global_position": view.global_position,
		"fly_scale": visual_scale(view),
		# CardVisual is center-anchored; size must match source or the art shifts.
		"size": view.size,
	}


static func origin_pose(control: Control) -> Dictionary:
	return {
		"global_position": control.global_position,
		"fly_scale": settle_fly_scale(control),
		"size": control.size,
	}


## World-ish fly scale for top_level motion. Omits [param view]'s own
## offset_transform (still applied while top_level); multiplies parent visuals * scale.
static func visual_scale(view: Control) -> Vector2:
	return _parent_visual_scale(view) * view.scale


static func control_visual_scale(c: Control) -> Vector2:
	if c.offset_transform_enabled:
		return c.offset_transform_scale * c.scale
	return c.scale


static func settle_fly_scale(parent: Control) -> Vector2:
	## Fly scale for a child with local scale ONE under [param parent].
	var s := control_visual_scale(parent)
	var node := parent.get_parent()
	while node is Control:
		s *= control_visual_scale(node as Control)
		node = node.get_parent()
	return s


## Global position [param view] will have after [method settle] at [param local_pos].
## Accounts for non-visual-only offset_transform (scale/pivot), unlike parent * local_pos.
static func settled_global_position(parent: Control, view: Control, local_pos: Vector2) -> Vector2:
	# Mirrors Control.get_transform() with scale ONE and position = local_pos.
	var pivot := view.get_combined_pivot_offset()
	var xform := Transform2D(view.rotation, Vector2.ONE, 0.0, pivot)
	xform = xform.translated_local(-pivot)
	if view.offset_transform_enabled and not view.offset_transform_visual_only:
		xform *= _offset_transform_of(view)
	xform.origin += local_pos
	return parent.get_global_transform() * xform.origin


static func fly_to(
	view: Control,
	dest_global_pos: Vector2,
	dest_fly_scale: Vector2,
	dest_size: Vector2 = Vector2.INF,
	duration: float = -1.0,
) -> void:
	if duration < 0.0:
		duration = CardAnim.move_duration()
	view.top_level = true
	# top_level skips parent modulate — copy seat dim onto the card for the flight.
	_copy_parent_dim(view)
	var tween := CardAnim.init_tween(view)
	tween.set_parallel(true)
	tween.tween_property(view, "global_position", dest_global_pos, duration)
	tween.tween_property(view, "scale", dest_fly_scale, duration)
	if dest_size.is_finite():
		tween.tween_property(view, "size", dest_size, duration)
		tween.tween_property(view, "custom_minimum_size", dest_size, duration)
	await tween.finished


static func settle(
	view: Control, parent: Control, local_pos: Vector2, slot_size: Vector2 = Vector2.INF
) -> void:
	view.top_level = false
	_clear_copied_dim(view)
	if view.get_parent() != parent:
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		parent.add_child(view)
	view.scale = Vector2.ONE
	if slot_size.is_finite():
		view.custom_minimum_size = slot_size
		view.size = slot_size
	view.position = local_pos


static func _offset_transform_of(view: Control) -> Transform2D:
	# Same construction as Control.get_offset_transform() (not bound in GDScript).
	var combined_translation := (
		view.offset_transform_position
		+ view.offset_transform_position_ratio * view.size
	)
	var combined_pivot := (
		view.offset_transform_pivot + view.offset_transform_pivot_ratio * view.size
	)
	var offset_xform := Transform2D(
		view.offset_transform_rotation,
		view.offset_transform_scale,
		0.0,
		combined_pivot + combined_translation,
	)
	return offset_xform.translated_local(-combined_pivot)


static func apply_start(view: Control, pose: Dictionary) -> void:
	view.top_level = true
	_copy_parent_dim(view)
	# Size before position: center-anchored visuals depend on size.
	if pose.has("size"):
		var s: Vector2 = pose["size"]
		view.custom_minimum_size = s
		view.size = s
	view.global_position = pose.get("global_position", view.global_position)
	view.scale = pose.get("fly_scale", Vector2.ONE)


## top_level breaks parent modulate inheritance; mirror RGB from the seat array.
static func _copy_parent_dim(view: Control) -> void:
	var parent := view.get_parent() as CanvasItem
	if parent == null:
		return
	var a := view.modulate.a
	view.modulate = Color(parent.modulate.r, parent.modulate.g, parent.modulate.b, a)


static func _clear_copied_dim(view: Control) -> void:
	var a := view.modulate.a
	view.modulate = Color(1.0, 1.0, 1.0, a)


static func _parent_visual_scale(view: Control) -> Vector2:
	var s := Vector2.ONE
	var node := view.get_parent()
	while node is Control:
		s *= control_visual_scale(node as Control)
		node = node.get_parent()
	return s
