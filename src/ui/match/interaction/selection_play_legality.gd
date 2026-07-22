class_name SelectionPlayLegality
extends RefCounted
## Client-side selection validity + INVALID/ACTIVE borders.


static func is_valid_selection(cards: Array[Card], state: GameState) -> bool:
	if cards.is_empty() or state == null:
		return false
	var result := PlayValidator.evaluate(cards, state.current_trick_combo)
	return bool(result.get("ok", false))


static func apply_borders(card_bases: Array, valid: bool) -> void:
	for item in card_bases:
		var base := item as CardBase
		if base == null:
			continue
		base.selection_invalid = base.selected and not valid
