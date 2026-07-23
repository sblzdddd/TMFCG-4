class_name MatchController
extends Node
## Host-authoritative match phase + play order. Clients only apply snapshots.

signal start_countdown_tick(seconds: int)

const TURN_GAP_SEC := 1.0
## Hold after soft-fill so local draw previews can finish before the lead acts.
## Keep in sync with [member CardDrawPreviewController.AUTO_DISMISS_SEC].
const DRAW_PREVIEW_SEC := 5.0
## Default / fallback turn length when room settings are unavailable.
const DEFAULT_TURN_COUNTDOWN_SEC := 15.0
## Extra host wait after client turn countdown before force-passing.
const TURN_TIMEOUT_GRACE_SEC := 15.0
## Shared lobby countdown before MatchStartFlow.begin (Toast on all peers).
const START_COUNTDOWN_SEC := 5

var _session: Node
var _rpc: MatchRpc
var state: MatchRuntimeState = MatchRuntimeState.new()
var _gap_token := 0
var _timeout_token := 0
## Last active uid we already armed empty-hand autoskip for (avoids double-pass).
var _autoskip_armed_uid := ""
## Room turn length used when the current host timeout was armed.
var _armed_countdown_sec := -1.0
var _timeout_arm_msec := 0
var _start_countdown_active := false


func setup(session: Node, shared_rpc: MatchRpc = null, connect_receive: bool = true) -> void:
	_session = session
	if shared_rpc != null:
		_rpc = shared_rpc
	else:
		_rpc = MatchRpc.new()
		_rpc.name = "MatchRpc"
		add_child(_rpc)
	if connect_receive and not _rpc.match_snapshot_received.is_connected(_on_match_snapshot):
		_rpc.match_snapshot_received.connect(_on_match_snapshot)
	if not session.room_changed.is_connected(_on_room_changed):
		session.room_changed.connect(_on_room_changed)


func clear() -> void:
	_gap_token += 1
	_timeout_token += 1
	_autoskip_armed_uid = ""
	_armed_countdown_sec = -1.0
	_timeout_arm_msec = 0
	_start_countdown_active = false
	state.clear()
	_emit_changed()


## Authoritative turn length from room settings (clients + host force-pass timer).
func turn_countdown_sec() -> float:
	if _session != null and _session.current_room != null:
		return float(_session.current_room.turn_countdown_sec)
	return DEFAULT_TURN_COUNTDOWN_SEC


func is_start_countdown_active() -> bool:
	return _start_countdown_active


func accepts_new_joins() -> bool:
	## Lobby-like phases: pre-match and between rematches.
	return MatchStartFlow.can_start(state.phase) and not _start_countdown_active


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


## Host: start or restart a match (countdown → announce → deal → TURN_PLAY).
func start_game() -> void:
	if _forward_host_command("start_game"):
		return
	if not _is_host():
		return
	if _start_countdown_active:
		return
	if _session == null or _session.match_card_controller == null:
		return
	var cards := _session.match_card_controller as MatchCardController
	if cards == null:
		return
	if state == null or not MatchStartFlow.can_start(state.phase):
		return
	_start_countdown_active = true
	_emit_changed()
	var countdown_ok := await _run_start_countdown()
	_start_countdown_active = false
	if not countdown_ok:
		_emit_start_countdown(0)
	_emit_changed()
	if not countdown_ok:
		return
	if not MatchStartFlow.begin(self, cards):
		return
	_gap_token += 1
	var token := _gap_token
	await get_tree().create_timer(MatchStartFlow.BROADCAST_SEC).timeout
	if token != _gap_token or not _is_host() or _session == null or _session.current_room == null:
		return
	MatchStartFlow.finish(self, cards)


## Tick START_COUNTDOWN_SEC on all room peers (Toast via RoomStartButton).
func _run_start_countdown() -> bool:
	_gap_token += 1
	var token := _gap_token
	for remaining in range(START_COUNTDOWN_SEC, 0, -1):
		_emit_start_countdown(remaining)
		await get_tree().create_timer(1.0).timeout
		if token != _gap_token or not _is_host() or _session == null or _session.current_room == null:
			return false
		if state == null or not MatchStartFlow.can_start(state.phase):
			return false
	return true


func _emit_start_countdown(seconds: int) -> void:
	## Listen-server host is not in get_member_peer_ids; notify local UI directly.
	if not NetEnv.is_dedicated_server():
		start_countdown_tick.emit(seconds)
	if _rpc == null:
		return
	var peers: Array = []
	if _session != null and _session.has_method("get_member_peer_ids"):
		peers = _session.get_member_peer_ids()
	_rpc.broadcast_start_countdown(seconds, peers)


## After a successful play: placements / end-game / game-over checks.
## Returns false when the match entered GAME_OVER (caller should not advance).
func on_play_committed(uid: String) -> bool:
	if not _is_host() or _session == null or _session.match_card_controller == null:
		return true
	var cards := _session.match_card_controller as MatchCardController
	if cards == null or cards.state == null:
		return true
	var deck_empty := cards.deck_size() <= 0
	if deck_empty and state.phase == MatchPhase.Phase.TURN_PLAY:
		state.phase = MatchPhase.Phase.END_GAME_PLAY
		cards.state.current_phase = MatchPhase.Phase.END_GAME_PLAY
	if PlacementTracker.place_if_needed(cards.state, uid, deck_empty):
		_broadcast()
	if PlacementTracker.finalize_if_done(cards.state, state.order):
		_enter_game_over()
		return false
	return true


func _enter_game_over() -> void:
	_gap_token += 1
	state.phase = MatchPhase.Phase.GAME_OVER
	state.active_uid = ""
	_broadcast()


## Advance turn. [param delay] > 0 clears active first so players can see the
## last play before the next seat lights up (debug Next Player uses 0).
func advance_turn(delay: float = 0.0) -> void:
	if _forward_host_command("advance_turn", {"delay": delay}):
		return
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
	if not MatchPhase.is_play_phase(state.phase):
		return
	var card_state: GameState = null
	if _session != null and _session.match_card_controller != null:
		card_state = _session.match_card_controller.get_state()
	var next_uid := PlacementTracker.next_active_after(
		card_state, state.order, state.active_uid
	)
	if delay > 0.0:
		_gap_token += 1
		var token := _gap_token
		var phase_at_gap := state.phase
		state.active_uid = ""
		_broadcast()
		await get_tree().create_timer(delay).timeout
		if token != _gap_token or not _is_host() or _session.current_room == null:
			return
		if state.phase != phase_at_gap:
			return
		state.active_uid = next_uid
		_broadcast()
		return
	state.active_uid = next_uid
	_broadcast()


func offset_active(offset: int = 1) -> void:
	if _forward_host_command("offset_active", {"offset": offset}):
		return
	if not _is_host() or state.active_uid.is_empty():
		return
	state.order.move_player(state.active_uid, offset)
	_broadcast()


func reverse_order() -> void:
	if _forward_host_command("reverse_order"):
		return
	if not _is_host():
		return
	state.order.reverse()
	_broadcast()


func end_round() -> void:
	if _forward_host_command("end_round"):
		return
	if not _is_host():
		return
	if state.order.is_empty():
		return
	_gap_token += 1
	var token := _gap_token
	var lead_uid := _trick_winner_uid()
	if lead_uid.is_empty() or not state.order.has(lead_uid):
		lead_uid = (
			state.order.next_after(state.active_uid) if not state.active_uid.is_empty() else ""
		)
	var cards: MatchCardController = null
	if _session != null and _session.match_card_controller != null:
		cards = _session.match_card_controller as MatchCardController
	# No draw left: reset combo / graveyards in place (skip ROUND_RESOLUTION).
	var deck_empty := cards == null or cards.deck_size() <= 0
	if state.phase == MatchPhase.Phase.END_GAME_PLAY or deck_empty:
		if cards != null:
			cards.end_round()
		_resume_after_round(cards, lead_uid, true)
		return
	state.phase = MatchPhase.Phase.ROUND_RESOLUTION
	state.active_uid = ""
	_broadcast()
	await get_tree().create_timer(MatchStartFlow.BROADCAST_SEC).timeout
	if token != _gap_token or not _is_host() or _session.current_room == null:
		return
	if state.phase != MatchPhase.Phase.ROUND_RESOLUTION:
		return
	if cards != null:
		cards.end_round()
		cards.draw_for_all_soft()
		deck_empty = cards.deck_size() <= 0
	_broadcast()
	await get_tree().create_timer(DRAW_PREVIEW_SEC).timeout
	if token != _gap_token or not _is_host() or _session.current_room == null:
		return
	if state.phase != MatchPhase.Phase.ROUND_RESOLUTION:
		return
	_resume_after_round(cards, lead_uid, deck_empty)


func _resume_after_round(
	cards: MatchCardController,
	lead_uid: String,
	end_game: bool,
) -> void:
	if end_game:
		state.phase = MatchPhase.Phase.END_GAME_PLAY
	else:
		state.phase = MatchPhase.Phase.TURN_PLAY
	var card_state: GameState = cards.get_state() if cards != null else null
	if not lead_uid.is_empty() and not PlacementTracker.is_placed(card_state, lead_uid):
		state.active_uid = lead_uid
	else:
		state.active_uid = PlacementTracker.next_active_after(
			card_state, state.order, lead_uid
		)
	_broadcast()
	if card_state != null and PlacementTracker.finalize_if_done(card_state, state.order):
		_enter_game_over()


## Empty-hand players auto-pass; placements when deck empty; end round if all out.
func _try_autoskip_active() -> void:
	if not _is_host():
		return
	if not MatchPhase.is_play_phase(state.phase):
		return
	if state.active_uid.is_empty():
		return
	if _session == null or _session.match_card_controller == null:
		return
	var cards := _session.match_card_controller as MatchCardController
	if cards == null:
		return
	if PlacementTracker.is_placed(cards.state, state.active_uid):
		advance_turn()
		return
	if not cards.is_hand_empty(state.active_uid):
		return
	var deck_empty := cards.deck_size() <= 0
	if deck_empty or state.phase == MatchPhase.Phase.END_GAME_PLAY:
		PlacementTracker.place_if_needed(cards.state, state.active_uid, true)
		if PlacementTracker.finalize_if_done(cards.state, state.order):
			_enter_game_over()
			return
		advance_turn()
		return
	if cards.all_hands_empty():
		end_round()
		return
	cards.handle_pass_for_uid(state.active_uid)


func _trick_winner_uid() -> String:
	if _session == null or _session.match_card_controller == null:
		return ""
	var card_state := _session.match_card_controller.get_state() as GameState
	if card_state == null or card_state.trick_winner_id == null:
		return ""
	return card_state.trick_winner_id.value


func end_game_play() -> void:
	if _forward_host_command("end_game_play"):
		return
	if not _is_host():
		return
	_gap_token += 1
	state.phase = MatchPhase.Phase.END_GAME_PLAY
	_broadcast()


func broadcast_state() -> void:
	_broadcast()


func execute_host_command(command: String, args: Dictionary = {}) -> void:
	match command:
		"start_game":
			# Keep coroutine on this Node (do not await static helpers).
			start_game()
		"advance_turn":
			advance_turn(float(args.get("delay", 0.0)))
		"offset_active":
			offset_active(int(args.get("offset", 1)))
		"reverse_order":
			reverse_order()
		"end_round":
			end_round()
		"end_game_play":
			end_game_play()
		"draw_for_all_soft":
			if _session != null and _session.match_card_controller != null:
				_session.match_card_controller.draw_for_all_soft(int(args.get("target", 5)))
		"draw_to_player":
			if _session != null and _session.match_card_controller != null:
				_session.match_card_controller.draw_to_player(
					str(args.get("uid", "")),
					int(args.get("count", 1)),
				)


func _forward_host_command(command: String, args: Dictionary = {}) -> bool:
	if ConnectionManager.is_server():
		return false
	if _session != null and _session.is_local_host() and _rpc != null:
		_rpc.send_host_command(command, args)
		return true
	return false


func _on_room_changed(room: RoomData) -> void:
	if room == null:
		_timeout_token += 1
		_armed_countdown_sec = -1.0
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
		_rearm_timeout_for_countdown_change()


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
		var peers: Array = []
		if _session != null and _session.has_method("get_member_peer_ids"):
			peers = _session.get_member_peer_ids()
		_rpc.broadcast(state.to_dict(), peers)
	if not _is_host():
		return
	if not MatchPhase.is_play_phase(state.phase) or state.active_uid.is_empty():
		_autoskip_armed_uid = ""
		_timeout_token += 1
		_armed_countdown_sec = -1.0
		return
	# Arm once per active seat so pass's own broadcast cannot re-autoskip.
	if _autoskip_armed_uid == state.active_uid:
		return
	_autoskip_armed_uid = state.active_uid
	call_deferred("_try_autoskip_active")
	_arm_turn_timeout(state.active_uid)


## Host: room turn_countdown_sec + grace; force-pass if the active seat never acts.
func _arm_turn_timeout(uid: String, remaining_override: float = -1.0) -> void:
	_timeout_token += 1
	var token := _timeout_token
	var limit := remaining_override
	if limit < 0.0:
		_armed_countdown_sec = turn_countdown_sec()
		_timeout_arm_msec = Time.get_ticks_msec()
		limit = _armed_countdown_sec + TURN_TIMEOUT_GRACE_SEC
	await get_tree().create_timer(limit).timeout
	if token != _timeout_token or not _is_host() or _session == null:
		return
	if not MatchPhase.is_play_phase(state.phase) or state.active_uid != uid:
		return
	if _session.match_card_controller == null:
		return
	_session.match_card_controller.handle_timeout_for_uid(uid)


## When host edits turn_countdown_sec mid-turn, keep elapsed wall time and re-arm.
func _rearm_timeout_for_countdown_change() -> void:
	if (
		not MatchPhase.is_play_phase(state.phase)
		or state.active_uid.is_empty()
		or _armed_countdown_sec < 0.0
	):
		return
	var new_sec := turn_countdown_sec()
	if is_equal_approx(new_sec, _armed_countdown_sec):
		return
	var elapsed := (Time.get_ticks_msec() - _timeout_arm_msec) / 1000.0
	_armed_countdown_sec = new_sec
	var remaining := new_sec + TURN_TIMEOUT_GRACE_SEC - elapsed
	if remaining <= 0.0:
		_timeout_token += 1
		if _session != null and _session.match_card_controller != null:
			_session.match_card_controller.handle_timeout_for_uid(state.active_uid)
		return
	_arm_turn_timeout(state.active_uid, remaining)


func _emit_changed() -> void:
	if _session != null:
		_session.match_changed.emit(state)


func _is_host() -> bool:
	return ConnectionManager.is_server()
