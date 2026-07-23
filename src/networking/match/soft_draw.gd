class_name SoftDraw
extends RefCounted
## Soft-fill hands toward a target, in play order from the trick winner.

const TARGET := 5


## Seat order for soft-fill / draw animation (winner first).
static func draw_uids(
	order: PlayerOrder,
	winner_uid: String,
	players: Array[PlayerState] = [],
) -> Array[String]:
	if order != null and not order.is_empty():
		return order.uids_from(winner_uid)
	var uids: Array[String] = []
	for player in players:
		if player != null and player.player_id != null:
			uids.append(player.player_id.value)
	if uids.is_empty():
		return uids
	var start_idx := 0
	if not winner_uid.is_empty():
		var found := uids.find(winner_uid)
		if found >= 0:
			start_idx = found
	var result: Array[String] = []
	for i in uids.size():
		result.append(uids[(start_idx + i) % uids.size()])
	return result


## Fill each hand toward [param target]. Returns uid -> moved cards.
static func apply(
	state: GameState,
	order: PlayerOrder,
	target: int = TARGET,
) -> Dictionary:
	var drawn_by_uid: Dictionary = {}
	if state == null or state.deck == null:
		return drawn_by_uid
	var winner := (
		state.trick_winner_id.value
		if state.trick_winner_id != null
		else ""
	)
	for uid in draw_uids(order, winner, state.players):
		var hand := state.get_player_hand(PlayerId.from_string(uid))
		if hand == null:
			continue
		var need := maxi(0, target - hand.get_size())
		if need <= 0:
			continue
		var n := mini(need, state.deck.get_size())
		if n <= 0:
			break
		var selected: Array[Card] = []
		for i in n:
			selected.append(state.deck.get_card(i))
		var moved := state.transfer_cards(state.deck, hand, selected, true)
		if not moved.is_empty():
			drawn_by_uid[uid] = moved
	return drawn_by_uid
