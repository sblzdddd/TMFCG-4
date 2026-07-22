class_name PlayCommit
extends RefCounted
## Validate and commit a play into GameState (no networking).


static func apply(state: GameState, uid: String, cards: Array[Card]) -> bool:
	if state == null or uid.is_empty() or cards.is_empty():
		return false
	var result := PlayValidator.evaluate(cards, state.current_trick_combo)
	if not bool(result.get("ok", false)):
		return false
	var combo: CardCombination = result.get("combo") as CardCombination
	var moved := state.record_play(PlayerId.from_string(uid), cards)
	if moved.is_empty():
		return false
	state.current_trick_combo = combo
	state.passes_count = 0
	state.trick_winner_id = PlayerId.from_string(uid)
	return true
