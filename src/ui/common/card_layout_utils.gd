class_name CardLayoutUtils
extends RefCounted
## Layout helpers for [CardBase] / card grid cells.

const CARD_SIZE := Vector2(300, 400)


## Sizes [param card] to [constant CARD_SIZE] and applies Control.scale.
## Returns a slot Control whose minimum size matches the scaled footprint.
static func create_scaled_slot(card: Control, display_scale: float) -> Control:
	var s := maxf(display_scale, 0.01)
	card.offset_transform_enabled = false
	card.offset_transform_scale = Vector2.ONE
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.scale = Vector2(s, s)
	card.pivot_offset = Vector2.ZERO

	var slot := Control.new()
	slot.custom_minimum_size = CARD_SIZE * s
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(card)
	card.position = Vector2.ZERO
	return slot
