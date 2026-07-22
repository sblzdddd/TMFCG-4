class_name PlacementTracker
extends RefCounted
## Finish-order helpers when hands empty and the deck cannot refill.


static func is_placed(state: GameState, uid: String) -> bool:
	if state == null or uid.is_empty():
		return false
	for placement in state.placements:
		if placement != null and placement.value == uid:
			return true
	return false


static func active_uids(state: GameState, order: PlayerOrder) -> Array[String]:
	var result: Array[String] = []
	if state == null or order == null:
		return result
	for uid in order.uids:
		if not is_placed(state, uid):
			result.append(uid)
	return result


static func next_active_after(state: GameState, order: PlayerOrder, uid: String) -> String:
	var actives := active_uids(state, order)
	if actives.is_empty():
		return ""
	var idx := actives.find(uid)
	if idx < 0:
		return actives[0]
	return actives[(idx + 1) % actives.size()]


static func place_if_needed(state: GameState, uid: String, deck_empty: bool) -> bool:
	if state == null or uid.is_empty() or is_placed(state, uid):
		return false
	if not deck_empty and state.current_phase != MatchPhase.Phase.END_GAME_PLAY:
		return false
	var hand := state.get_player_hand(PlayerId.from_string(uid))
	if hand == null or hand.get_size() > 0:
		return false
	state.placements.append(PlayerId.from_string(uid))
	return true


## If only one (or zero) active players remain, place the last and return true for GAME_OVER.
static func finalize_if_done(state: GameState, order: PlayerOrder) -> bool:
	if state == null or order == null:
		return false
	var actives := active_uids(state, order)
	if actives.size() > 1:
		return false
	if actives.size() == 1 and not is_placed(state, actives[0]):
		state.placements.append(PlayerId.from_string(actives[0]))
	return true
