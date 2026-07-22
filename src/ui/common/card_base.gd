class_name CardBase
extends Control
## Interactive card root for [code]card_base.tscn[/code].
## Face/back flip is driven by [member rotation_factor] (-1 back … +1 face).

signal hovered(card: CardBase)
signal unhovered(card: CardBase)
signal pressed(card: CardBase)

const SELECT_OFFSET_Y := -24.0
const CARD_SIZE := Vector2(300, 400)

@export var visual: CardVisual
@export var back: ColorRect

@export var interactable: bool = true:
	set(value):
		interactable = value
		if is_node_ready():
			visual.mouse_filter = (
				Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
			)

@export var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		if is_node_ready():
			_refresh_border()
			_apply_select_offset(true)

@export_range(-1.0, 1.0) var rotation_factor: float = 1.0:
	set(value):
		if rotation_factor == value:
			return
		rotation_factor = value
		if is_node_ready():
			_apply_rotation_factor()

var _hovering := false
var _pending_card: CardData = null
var _flip_tween: Tween
var _select_tween: Tween


func _ready() -> void:
	# Keep mouse hit area matched to the scaled/offset visual, not the full CARD_SIZE rect.
	offset_transform_visual_only = false
	visual.mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactable else Control.MOUSE_FILTER_IGNORE
	)
	visual.mouse_entered.connect(_on_visual_mouse_entered)
	visual.mouse_exited.connect(_on_visual_mouse_exited)
	visual.gui_input.connect(_on_visual_gui_input)
	if _pending_card != null:
		_apply_card_data(_pending_card)
		_pending_card = null
	_apply_rotation_factor()
	_refresh_border()
	_apply_select_offset(false)


func set_face_up(face_up: bool, animate: bool = true) -> void:
	var target := 1.0 if face_up else -1.0
	if not animate:
		rotation_factor = target
		return
	_flip_tween = CardAnim.init_tween(self, _flip_tween)
	_flip_tween.tween_property(self, "rotation_factor", target, CardAnim.flip_duration())


func flip_to_face(delay: float = 0.0) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(
			func() -> void: set_face_up(true, true),
			CONNECT_ONE_SHOT,
		)
	else:
		set_face_up(true, true)


func is_face_up() -> bool:
	return rotation_factor > 0.0


func set_card_data(card_data: CardData) -> void:
	if is_node_ready():
		_apply_card_data(card_data)
	else:
		_pending_card = card_data


## Sizes CardBase to CardVisual and applies Control.scale for UI grids.
## Returns a slot Control whose minimum size matches the scaled footprint.
func create_scaled_slot(display_scale: float) -> Control:
	var s := maxf(display_scale, 0.01)
	offset_transform_enabled = false
	offset_transform_scale = Vector2.ONE
	scale = Vector2(s, s)
	pivot_offset = Vector2.ZERO

	var slot := Control.new()
	slot.custom_minimum_size = CARD_SIZE * s
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(self)
	position = Vector2.ZERO
	return slot


func get_card_data() -> CardData:
	return visual.card


func _apply_rotation_factor() -> void:
	if rotation_factor <= 0.0:
		back.visible = true
		back.scale = Vector2(absf(rotation_factor), 1.0)
		visual.scale = Vector2(0.0, 1.0)
	else:
		back.visible = false
		visual.scale = Vector2(rotation_factor, 1.0)
		back.scale = Vector2(0.0, 1.0)


func _on_visual_mouse_entered() -> void:
	_hovering = true
	_refresh_border()
	hovered.emit(self)


func _on_visual_mouse_exited() -> void:
	_hovering = false
	_refresh_border()
	unhovered.emit(self)


func _on_visual_gui_input(event: InputEvent) -> void:
	if not interactable:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(self)
			accept_event()


func _apply_card_data(card_data: CardData) -> void:
	visual.card = card_data
	if card_data != null and card_data.visual != null:
		visual.character = card_data.visual
	else:
		visual.character = null


func _refresh_border() -> void:
	if selected:
		visual.set_border_state(CardVisual.BorderState.ACTIVE)
	elif _hovering and interactable:
		visual.set_border_state(CardVisual.BorderState.HOVER)
	else:
		visual.set_border_state(CardVisual.BorderState.NORMAL)


func _apply_select_offset(animate: bool) -> void:
	if not offset_transform_enabled:
		offset_transform_enabled = true
	offset_transform_visual_only = false
	var target_y := SELECT_OFFSET_Y if selected else 0.0
	if not animate or not is_inside_tree() or Engine.is_editor_hint():
		if _select_tween != null:
			_select_tween.kill()
			_select_tween = null
		offset_transform_position.y = target_y
		return
	_select_tween = CardAnim.init_tween(self, _select_tween)
	_select_tween.tween_property(
		self, "offset_transform_position:y", target_y, CardAnim.select_duration()
	)
