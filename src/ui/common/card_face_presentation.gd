class_name CardFacePresentation
extends RefCounted
## Flip, selection offset, and border visuals for a [CardBase].

const SELECT_OFFSET_Y := -24.0

var _host: CardBase
var _flip_tween: Tween
var _select_tween: Tween


func setup(host: CardBase) -> void:
	_host = host


func apply_rotation_factor(factor: float) -> void:
	var visual := _host.visual
	var back := _host.back
	if factor <= 0.0:
		back.visible = true
		back.scale = Vector2(absf(factor), 1.0)
		visual.scale = Vector2(0.0, 1.0)
	else:
		back.visible = false
		visual.scale = Vector2(factor, 1.0)
		back.scale = Vector2(0.0, 1.0)


func refresh_border() -> void:
	var visual := _host.visual
	if _host.selected and _host.selection_invalid:
		visual.set_border_state(CardVisual.BorderState.INVALID)
	elif _host.selected:
		visual.set_border_state(CardVisual.BorderState.ACTIVE)
	elif _host.is_hovering() and _host.interactable:
		visual.set_border_state(CardVisual.BorderState.HOVER)
	else:
		visual.set_border_state(CardVisual.BorderState.NORMAL)


func apply_select_offset(animate: bool) -> void:
	if not _host.offset_transform_enabled:
		_host.offset_transform_enabled = true
	_host.offset_transform_visual_only = false
	var target_y := SELECT_OFFSET_Y if _host.selected else 0.0
	if not animate or not _host.is_inside_tree() or Engine.is_editor_hint():
		if _select_tween != null:
			_select_tween.kill()
			_select_tween = null
		_host.offset_transform_position.y = target_y
		return
	_select_tween = CardAnim.init_tween(_host, _select_tween)
	_select_tween.tween_property(
		_host, "offset_transform_position:y", target_y, CardAnim.select_duration()
	)


func animate_flip_to(target_factor: float) -> void:
	_flip_tween = CardAnim.init_tween(_host, _flip_tween)
	_flip_tween.tween_property(_host, "rotation_factor", target_factor, CardAnim.flip_duration())
