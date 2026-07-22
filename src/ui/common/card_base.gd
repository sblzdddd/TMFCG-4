class_name CardBase
extends Control
## Interactive card root for [code]card_base.tscn[/code].

signal hovered(card: CardBase)
signal unhovered(card: CardBase)
signal pressed(card: CardBase)

const CARD_SIZE := CardLayoutUtils.CARD_SIZE
const SELECT_OFFSET_Y := -24.0
const ACTIVE_HAND_INFO_HOVER_DELAY := CardInfoInteraction.ACTIVE_HAND_HOVER_DELAY

@export var visual: CardVisual
@export var back: ColorRect

## When true (match default), only skill cards show the info popup. Deck panels set false.
@export var info_skills_only: bool = true:
	set(value):
		info_skills_only = value
		if _info != null:
			_info.skills_only = value
		if is_node_ready():
			_refresh_mouse_filter()

## Desktop hover delay before info popup. Active hand sets this to 1s; touch hold ignores it.
@export var info_hover_delay: float = 0.0:
	set(value):
		info_hover_delay = value
		if _info != null:
			_info.hover_delay = value

@export var interactable: bool = true:
	set(value):
		interactable = value
		if is_node_ready():
			_refresh_mouse_filter()
			_refresh_border()

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
			_refresh_mouse_filter()

var _hovering := false
var _pending_card: CardData = null
var _flip_tween: Tween
var _select_tween: Tween
var _info: CardInfoInteraction


func _ready() -> void:
	# Keep mouse hit area matched to the scaled/offset visual, not the full CARD_SIZE rect.
	offset_transform_visual_only = false
	_info = CardInfoInteraction.new()
	_info.skills_only = info_skills_only
	_info.hover_delay = info_hover_delay
	_info.setup(self)
	visual.mouse_entered.connect(_on_visual_mouse_entered)
	visual.mouse_exited.connect(_on_visual_mouse_exited)
	visual.gui_input.connect(_on_visual_gui_input)
	if _pending_card != null:
		_apply_card_data(_pending_card)
		_pending_card = null
	_apply_rotation_factor()
	_refresh_mouse_filter()
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


func is_hovering() -> bool:
	return _hovering


func set_card_data(card_data: CardData) -> void:
	if is_node_ready():
		_apply_card_data(card_data)
	else:
		_pending_card = card_data


## Sizes CardBase to CardVisual and applies Control.scale for UI grids.
## Returns a slot Control whose minimum size matches the scaled footprint.
func create_scaled_slot(display_scale: float) -> Control:
	return CardLayoutUtils.create_scaled_slot(self, display_scale)


func get_card_data() -> CardData:
	return visual.card


## Sync mouse filter from selection + info-hover eligibility.
## Prefer this over setting [member visual].mouse_filter directly.
func refresh_interaction() -> void:
	_refresh_mouse_filter()


func _apply_rotation_factor() -> void:
	if rotation_factor <= 0.0:
		back.visible = true
		back.scale = Vector2(absf(rotation_factor), 1.0)
		visual.scale = Vector2(0.0, 1.0)
	else:
		back.visible = false
		visual.scale = Vector2(rotation_factor, 1.0)
		back.scale = Vector2(0.0, 1.0)


func _refresh_mouse_filter() -> void:
	if visual == null:
		return
	# Face-up cards must STOP so stacked normals occlude skills behind them.
	# Info popup is gated separately via CardInfoInteraction.
	var face_up := is_face_up()
	var stop_face := interactable or face_up
	visual.mouse_filter = (
		Control.MOUSE_FILTER_STOP if stop_face else Control.MOUSE_FILTER_IGNORE
	)
	if back != null:
		back.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE if face_up else Control.MOUSE_FILTER_STOP
		)


func _on_visual_mouse_entered() -> void:
	_hovering = true
	_refresh_border()
	hovered.emit(self)
	_info.on_hover_entered()


func _on_visual_mouse_exited() -> void:
	_hovering = false
	_refresh_border()
	unhovered.emit(self)
	_info.on_hover_exited()


func _on_visual_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_info.begin_touch_hold()
		else:
			if _info.end_touch_hold() and interactable:
				pressed.emit(self)
		accept_event()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		# Emulated mouse during an active touch hold — ignore.
		if _info.touch_holding:
			accept_event()
			return
		if mb.pressed and interactable:
			pressed.emit(self)
			accept_event()


func _apply_card_data(card_data: CardData) -> void:
	visual.card = card_data
	if card_data != null and card_data.visual != null:
		visual.character = card_data.visual
	else:
		visual.character = null
	_refresh_mouse_filter()


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
