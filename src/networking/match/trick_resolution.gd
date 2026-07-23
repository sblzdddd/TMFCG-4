class_name TrickResolution
extends RefCounted
## When consecutive passes end the current trick.


## True when enough seats have passed for the trick to resolve.
## If the winner is still active, the turn must wrap back to them.
## If the winner already finished (placed), every remaining seat must pass once.
static func should_end_by_passes(
	state: GameState,
	order: PlayerOrder,
	next_active_uid: String,
) -> bool:
	if state == null or order == null:
		return false
	var winner := (
		state.trick_winner_id.value
		if state.trick_winner_id != null
		else ""
	)
	if winner.is_empty():
		return false
	var actives := PlacementTracker.active_uids(state, order)
	var active_n := actives.size()
	if active_n <= 0:
		return false
	var winner_active := actives.has(winner)
	if winner_active:
		return (
			next_active_uid == winner
			and state.passes_count >= maxi(active_n - 1, 1)
		)
	return state.passes_count >= active_n
