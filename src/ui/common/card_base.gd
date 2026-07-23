class_name CardBase
extends Control
## Interactive card root for [code]card_base.tscn[/code].
## Composes [CardInfoInteraction], [CardPointerInteraction], and [CardFacePresentation].

signal hovered(card: CardBase)
signal unhovered(card: CardBase)
## [param from_touch] is true when the press came from a short ScreenTouch tap
## (long-press info hold / touch-drag never emits this).
signal pressed(card: CardBase, from_touch: bool)
## Real touch down on this card (not emulated-from-mouse).
signal touch_started(card: CardBase)
## Finger moved while holding; [param global_pos] is canvas position under the finger.
signal touch_dragged(card: CardBase, global_pos: Vector2)
## Real touch up. [param as_tap] is true for a short stationary tap (selection).
signal touch_ended(card: CardBase, as_tap: bool)

const CARD_SIZE := CardLayoutUtils.CARD_SIZE
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
			_pointer.refresh_mouse_filter()

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
			_pointer.refresh_mouse_filter()
			_face.refresh_border()

## When true, face-up hit targets use [constant Control.MOUSE_FILTER_PASS] and do not
## accept press events, so a parent [ScrollContainer] can drag-scroll (deck preview).
@export var pass_scroll_input: bool = false:
	set(value):
		pass_scroll_input = value
		if is_node_ready():
			_pointer.refresh_mouse_filter()

@export var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		if not selected:
			selection_invalid = false
		if is_node_ready():
			_face.refresh_border()
			_face.apply_select_offset(true)

## When selected but the current selection is not a legal play.
var selection_invalid: bool = false:
	set(value):
		if selection_invalid == value:
			return
		selection_invalid = value
		if is_node_ready():
			_face.refresh_border()

@export_range(-1.0, 1.0) var rotation_factor: float = 1.0:
	set(value):
		if rotation_factor == value:
			return
		rotation_factor = value
		if is_node_ready():
			_face.apply_rotation_factor(rotation_factor)
			_pointer.refresh_mouse_filter()

var _pending_card: CardData = null
var _info: CardInfoInteraction
var _pointer: CardPointerInteraction
var _face: CardFacePresentation


func _ready() -> void:
	# Keep mouse hit area matched to the scaled/offset visual, not the full CARD_SIZE rect.
	offset_transform_visual_only = false
	_info = CardInfoInteraction.new()
	_info.skills_only = info_skills_only
	_info.hover_delay = info_hover_delay
	_info.setup(self)
	_pointer = CardPointerInteraction.new()
	_pointer.setup(self, _info)
	_face = CardFacePresentation.new()
	_face.setup(self)
	if _pending_card != null:
		_apply_card_data(_pending_card)
		_pending_card = null
	_face.apply_rotation_factor(rotation_factor)
	_pointer.refresh_mouse_filter()
	_face.refresh_border()
	_face.apply_select_offset(false)


func set_face_up(face_up: bool, animate: bool = true) -> void:
	var target := 1.0 if face_up else -1.0
	if not animate:
		rotation_factor = target
		return
	_face.animate_flip_to(target)


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
	return _pointer != null and _pointer.hovering


func is_touch_holding() -> bool:
	return _info != null and _info.touch_holding


## Mark the active touch as a drag (cancels info hold / tap). Used by hand multi-select.
func mark_touch_moved() -> void:
	if _info != null:
		_info.mark_touch_moved()


## Pointer-module callbacks (signal ownership stays on CardBase).

func on_pointer_hover_entered() -> void:
	_face.refresh_border()
	hovered.emit(self)
	_info.on_hover_entered()


func on_pointer_hover_exited() -> void:
	_face.refresh_border()
	unhovered.emit(self)
	_info.on_hover_exited()


func on_pointer_pressed(from_touch: bool) -> void:
	pressed.emit(self, from_touch)


func on_pointer_touch_started() -> void:
	touch_started.emit(self)


func on_pointer_touch_dragged(global_pos: Vector2) -> void:
	touch_dragged.emit(self, global_pos)


func on_pointer_touch_ended(as_tap: bool) -> void:
	touch_ended.emit(self, as_tap)
	if as_tap:
		pressed.emit(self, true)


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


func refresh_interaction() -> void:
	if _pointer != null:
		_pointer.refresh_mouse_filter()


func _apply_card_data(card_data: CardData) -> void:
	visual.card = card_data
	if card_data != null and card_data.visual != null:
		visual.character = card_data.visual
	else:
		visual.character = null
	if _pointer != null:
		_pointer.refresh_mouse_filter()
