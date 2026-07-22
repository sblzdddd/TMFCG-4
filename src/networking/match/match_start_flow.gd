class_name MatchStartFlow
extends RefCounted
## Sync helpers for host start / restart. Timers stay on MatchController.

const BROADCAST_SEC := 1.5


static func can_start(phase: MatchPhase.Phase) -> bool:
	return (
		phase == MatchPhase.Phase.INITIALIZATION
		or phase == MatchPhase.Phase.GAME_OVER
	)


## Reset if needed, sync order, build wild deck, enter ROUND_RESOLUTION + broadcast.
## Returns false if start was refused.
static func begin(match_ctrl: MatchController, card_ctrl: MatchCardController) -> bool:
	if match_ctrl == null or card_ctrl == null:
		return false
	var state := match_ctrl.state
	if state == null or not can_start(state.phase):
		push_warning(
			"MatchStartFlow: refuse begin (phase=%s)"
			% (MatchPhase.Phase.find_key(state.phase) if state else "null")
		)
		return false
	if state.phase == MatchPhase.Phase.GAME_OVER:
		match_ctrl.clear()
		card_ctrl.clear()
		state = match_ctrl.state
	match_ctrl.sync_members_from_room()
	if state.order.is_empty():
		push_warning("MatchStartFlow: refuse begin (empty order)")
		return false
	card_ctrl.rebuild_match_deck()
	state.phase = MatchPhase.Phase.ROUND_RESOLUTION
	state.active_uid = ""
	match_ctrl.broadcast_state()
	return true


## Soft-draw and enter TURN_PLAY with a random lead (call after BROADCAST_SEC).
static func finish(match_ctrl: MatchController, card_ctrl: MatchCardController) -> void:
	if match_ctrl == null or card_ctrl == null:
		return
	var state := match_ctrl.state
	if state == null or state.phase != MatchPhase.Phase.ROUND_RESOLUTION:
		return
	card_ctrl.draw_for_all_soft()
	state.phase = MatchPhase.Phase.TURN_PLAY
	state.active_uid = state.order.random_uid() if not state.order.is_empty() else ""
	match_ctrl.broadcast_state()
