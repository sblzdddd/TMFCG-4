class_name CardBase
extends Control
## Interactive card root: hover/click over CardVisual bounds; border via CardVisual.

signal hovered(card: CardBase)
signal unhovered(card: CardBase)
signal pressed(card: CardBase)

@onready var visual: CardVisual = $CardVisual

@export var interactable: bool = true
@export var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		_refresh_border()

var _hovering := false
var _pending_card: CardData = null
var _has_pending_card := false
var _picking_wired := false


func _ready() -> void:
	visual = get_node_or_null("CardVisual") as CardVisual
	_sync_size_from_visual()
	_wire_picking()
	if _has_pending_card:
		_apply_card_data(_pending_card)
		_has_pending_card = false
	_refresh_border()


func _wire_picking() -> void:
	if _picking_wired:
		return
	var vis := _visual()
	if vis == null:
		return
	# Root ignores picks; CardVisual owns the hit target. Descendants must not steal input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in vis.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not vis.mouse_entered.is_connected(_on_visual_mouse_entered):
		vis.mouse_entered.connect(_on_visual_mouse_entered)
	if not vis.mouse_exited.is_connected(_on_visual_mouse_exited):
		vis.mouse_exited.connect(_on_visual_mouse_exited)
	if not vis.gui_input.is_connected(_on_visual_gui_input):
		vis.gui_input.connect(_on_visual_gui_input)
	_picking_wired = true


func _on_visual_mouse_entered() -> void:
	if not interactable:
		return
	_hovering = true
	_refresh_border()
	hovered.emit(self)


func _on_visual_mouse_exited() -> void:
	if not _hovering:
		return
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


func set_card_data(card_data: CardData) -> void:
	if is_node_ready():
		_apply_card_data(card_data)
	else:
		_pending_card = card_data
		_has_pending_card = true


## Sizes CardBase to CardVisual and applies Control.scale for UI grids.
## Returns a slot Control whose minimum size matches the scaled footprint.
func create_scaled_slot(display_scale: float) -> Control:
	var s := maxf(display_scale, 0.01)
	var base := _visual_base_size()
	custom_minimum_size = base
	size = base
	offset_transform_enabled = false
	offset_transform_scale = Vector2.ONE
	scale = Vector2(s, s)
	pivot_offset = Vector2.ZERO

	var slot := Control.new()
	slot.custom_minimum_size = base * s
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(self)
	position = Vector2.ZERO
	return slot


func get_card_data() -> CardData:
	var vis := _visual()
	return vis.card if vis else null


func _apply_card_data(card_data: CardData) -> void:
	var vis := _visual()
	if vis == null:
		return
	vis.card = card_data
	if card_data != null and card_data.visual != null:
		vis.character = card_data.visual
	else:
		vis.character = null


func _visual() -> CardVisual:
	if visual != null:
		return visual
	return get_node_or_null("CardVisual") as CardVisual


func _sync_size_from_visual() -> void:
	var base := _visual_base_size()
	custom_minimum_size = base
	size = base


func _visual_base_size() -> Vector2:
	var vis := _visual()
	if vis != null:
		if vis.custom_minimum_size != Vector2.ZERO:
			return vis.custom_minimum_size
		if vis.size != Vector2.ZERO:
			return vis.size
	return Vector2(300, 400)


func _refresh_border() -> void:
	var vis := _visual()
	if vis == null:
		return
	if selected:
		vis.set_border_state(CardVisual.BorderState.ACTIVE)
	elif _hovering and interactable:
		vis.set_border_state(CardVisual.BorderState.HOVER)
	else:
		vis.set_border_state(CardVisual.BorderState.NORMAL)
