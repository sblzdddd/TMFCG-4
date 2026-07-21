class_name CardPose
extends RefCounted
## Capture / fly / settle helpers for cross-array card motion.

const ANIM := 0.6


static func capture(view: Control) -> Dictionary:
	return {
		"global_position": view.global_position,
		"fly_scale": visual_scale(view),
	}


static func origin_pose(control: Control) -> Dictionary:
	return {
		"global_position": control.global_position,
		"fly_scale": settle_fly_scale(control),
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


static func fly_to(
	view: Control,
	dest_global_pos: Vector2,
	dest_fly_scale: Vector2,
	duration: float = ANIM,
) -> void:
	view.top_level = true
	var tween := TweenUtils.init_tween(view, null)
	tween.set_parallel(true)
	tween.tween_property(view, "global_position", dest_global_pos, duration)
	tween.tween_property(view, "scale", dest_fly_scale, duration)
	await tween.finished


static func settle(view: Control, parent: Control, local_pos: Vector2) -> void:
	view.top_level = false
	if view.get_parent() != parent:
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		parent.add_child(view)
	view.scale = Vector2.ONE
	view.position = local_pos


static func apply_start(view: Control, pose: Dictionary) -> void:
	view.top_level = true
	view.global_position = pose.get("global_position", view.global_position)
	view.scale = pose.get("fly_scale", Vector2.ONE)


static func _parent_visual_scale(view: Control) -> Vector2:
	var s := Vector2.ONE
	var node := view.get_parent()
	while node is Control:
		s *= control_visual_scale(node as Control)
		node = node.get_parent()
	return s
