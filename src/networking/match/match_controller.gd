class_name MatchController
extends Node
## Host-authoritative match phase + play order. Clients only apply snapshots.

const TURN_GAP_SEC := 1.0
## Hold after soft-fill so local draw previews can finish before the lead acts.
## Keep in sync with [member CardDrawPreviewController.AUTO_DISMISS_SEC].
const DRAW_PREVIEW_SEC := 5.0
## Default / fallback turn length when room settings are unavailable.
const DEFAULT_TURN_COUNTDOWN_SEC := 15.0
## Extra host wait after client turn countdown before force-passing.
const TURN_TIMEOUT_GRACE_SEC := 10.0

var _session: RoomSessionNode
var _rpc: MatchRpc
var state: MatchRuntimeState = MatchRuntimeState.new()
var _gap_token := 0
var _timeout_token := 0
## Last active uid we already armed empty-hand autoskip for (avoids double-pass).
var _autoskip_armed_uid := ""


func setup(session: RoomSessionNode) -> void:
	_session = session
	_rpc = MatchRpc.new()
	_rpc.name = "MatchRpc"
	add_child(_rpc)
	_rpc.match_snapshot_received.connect(_on_match_snapshot)
	session.room_changed.connect(_on_room_changed)


func clear() -> void:
	_gap_token += 1
	_timeout_token += 1
	_autoskip_armed_uid = ""
	state.clear()
	_emit_changed()


## Client-facing turn length from room settings (default 30s).
func turn_countdown_sec() -> float:
	if _session != null and _session.current_room != null:
		return float(_session.current_room.turn_countdown_sec)
	return DEFAULT_TURN_COUNTDOWN_SEC


func accepts_new_joins() -> bool:
	return state.phase == MatchPhase.Phase.INITIALIZATION


func get_state() -> MatchRuntimeState:
	return state


## Host: rebuild order from room members while still initializing.
func sync_members_from_room() -> void:
	if not _is_host() or _session.current_room == null:
		return
	if state.phase != MatchPhase.Phase.INITIALIZATION:
		return
	var member_uids: Array[String] = []
	for member in _session.current_room.get_members():
		member_uids.append(member.uid)
	state.order.ensure_members(member_uids)
	if not state.active_uid.is_empty() and not state.order.has(state.active_uid):
		state.active_uid = ""
	_broadcast()


## Host: remove a player from the order ring (leave / kick / grace).
func on_member_removed(uid: String) -> void:
	if not _is_host() or uid.is_empty():
		return
	var was_active := state.active_uid == uid
	var next_uid := state.order.next_after(uid) if was_active else state.active_uid
	state.order.remove(uid)
	if state.order.is_empty():
		state.active_uid = ""
	elif was_active:
		state.active_uid = next_uid if state.order.has(next_uid) else (
			state.order.uids[0] if not state.order.is_empty() else ""
		)
	_broadcast()


## Advance turn. [param delay] > 0 clears active first so players can see the
## last play before the next seat lights up (debug Next Player uses 0).
func advance_turn(delay: float = 0.0) -> void:
	if not _is_host():
		return
	if state.order.is_empty():
		sync_members_from_room()
	if state.order.is_empty():
		return
	if state.phase == MatchPhase.Phase.INITIALIZATION:
		state.phase = MatchPhase.Phase.TURN_PLAY
		state.active_uid = state.order.random_uid()
		_broadcast()
		return
	if state.phase != MatchPhase.Phase.TURN_PLAY:
		return
	var next_uid := state.order.next_after(state.active_uid)
	if delay > 0.0:
		_gap_token += 1
		var token := _gap_token
		state.active_uid = ""
		_broadcast()
		await get_tree().create_timer(delay).timeout
		if token != _gap_token or not _is_host() or _session.current_room == null:
			return
		if state.phase != MatchPhase.Phase.TURN_PLAY:
			return
		state.active_uid = next_uid
		_broadcast()
		return
	state.active_uid = next_uid
	_broadcast()


func offset_active(offset: int = 1) -> void:
	if not _is_host() or state.active_uid.is_empty():
		return
	state.order.move_player(state.active_uid, offset)
	_broadcast()


func reverse_order() -> void:
	if not _is_host():
		return
	state.order.reverse()
	_broadcast()


func end_round() -> void:
	if not _is_host():
		return
	if state.order.is_empty():
		return
	_gap_token += 1
	var token := _gap_token
	# Prefer the trick winner as next lead; fall back to next after last passer.
	var lead_uid := _trick_winner_uid()
	if lead_uid.is_empty() or not state.order.has(lead_uid):
		lead_uid = (
			state.order.next_after(state.active_uid) if not state.active_uid.is_empty() else ""
		)
	state.phase = MatchPhase.Phase.ROUND_RESOLUTION
	state.active_uid = ""
	if _session != null and _session.match_card_controller != null:
		_session.match_card_controller.end_round()
		_session.match_card_controller.draw_for_all_soft()
	_broadcast()
	# Always hold for draw preview (including empty "no cards drawn" overlay).
	await get_tree().create_timer(DRAW_PREVIEW_SEC).timeout
	if token != _gap_token or not _is_host() or _session.current_room == null:
		return
	if state.phase != MatchPhase.Phase.ROUND_RESOLUTION:
		return
	state.phase = MatchPhase.Phase.TURN_PLAY
	if not lead_uid.is_empty() and state.order.has(lead_uid):
		state.active_uid = lead_uid
	elif not state.order.is_empty():
		state.active_uid = state.order.uids[0]
	_broadcast()


func _trick_winner_uid() -> String:
	if _session == null or _session.match_card_controller == null:
		return ""
	var card_state := _session.match_card_controller.get_state()
	if card_state == null or card_state.trick_winner_id == null:
		return ""
	return card_state.trick_winner_id.value


## Empty-hand players auto-pass; if everyone is out, end the round (or game if
## the deck cannot refill).
func _try_autoskip_active() -> void:
	if not _is_host():
		return
	if state.phase != MatchPhase.Phase.TURN_PLAY or state.active_uid.is_empty():
		return
	if _session == null or _session.match_card_controller == null:
		return
	var cards := _session.match_card_controller
	if not cards.is_hand_empty(state.active_uid):
		return
	if cards.all_hands_empty():
		if cards.deck_size() <= 0:
			end_game_play()
			return
		end_round()
		return
	cards.handle_pass_for_uid(state.active_uid)


func end_game_play() -> void:
	if not _is_host():
		return
	_gap_token += 1
	state.phase = MatchPhase.Phase.END_GAME_PLAY
	_broadcast()


func broadcast_state() -> void:
	_broadcast()


func _on_room_changed(room: RoomData) -> void:
	if room == null:
		state.clear()
		_emit_changed()
		return
	if _is_host():
		if state.phase == MatchPhase.Phase.INITIALIZATION:
			sync_members_from_room()
		else:
			# Drop uids that left even mid-match (kick/grace already calls on_member_removed,
			# but reconcile defensively).
			_reconcile_removed_members(room)


func _reconcile_removed_members(room: RoomData) -> void:
	var member_set: Dictionary = {}
	for member in room.get_members():
		member_set[member.uid] = true
	var removed: Array[String] = []
	for uid in state.order.uids:
		if not member_set.has(uid):
			removed.append(uid)
	for uid in removed:
		on_member_removed(uid)


func _on_match_snapshot(snapshot: Dictionary) -> void:
	if _session.is_leaving_voluntarily():
		return
	state = MatchRuntimeState.from_dict(snapshot)
	_emit_changed()


func _broadcast() -> void:
	if (
		_session != null
		and _session.match_card_controller != null
	):
		_session.match_card_controller.sync_match_runtime(state.active_uid, state.phase)
	_emit_changed()
	if _is_host() and _rpc != null:
		_rpc.broadcast(state.to_dict())
	if not _is_host():
		return
	if state.phase != MatchPhase.Phase.TURN_PLAY or state.active_uid.is_empty():
		_autoskip_armed_uid = ""
		_timeout_token += 1
		return
	# Arm once per active seat so pass's own broadcast cannot re-autoskip.
	if _autoskip_armed_uid == state.active_uid:
		return
	_autoskip_armed_uid = state.active_uid
	call_deferred("_try_autoskip_active")
	_arm_turn_timeout(state.active_uid)


## Host: countdown + grace; force-pass if the active seat never acts.
func _arm_turn_timeout(uid: String) -> void:
	_timeout_token += 1
	var token := _timeout_token
	var limit := turn_countdown_sec() + TURN_TIMEOUT_GRACE_SEC
	await get_tree().create_timer(limit).timeout
	if token != _timeout_token or not _is_host() or _session == null:
		return
	if state.phase != MatchPhase.Phase.TURN_PLAY or state.active_uid != uid:
		return
	if _session.match_card_controller == null:
		return
	_session.match_card_controller.handle_timeout_for_uid(uid)


func _emit_changed() -> void:
	if _session != null:
		_session.match_changed.emit(state)


func _is_host() -> bool:
	return _session != null and _session.is_local_host()
