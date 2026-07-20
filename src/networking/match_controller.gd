class_name MatchController
extends Node
## Host-authoritative match phase + play order. Clients only apply snapshots.

var _session: RoomSessionNode
var _rpc: MatchRpc
var state: MatchRuntimeState = MatchRuntimeState.new()


func setup(session: RoomSessionNode) -> void:
	_session = session
	_rpc = MatchRpc.new()
	_rpc.name = "MatchRpc"
	add_child(_rpc)
	_rpc.match_snapshot_received.connect(_on_match_snapshot)
	session.room_changed.connect(_on_room_changed)


func clear() -> void:
	state.clear()
	_emit_changed()


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


func advance_turn() -> void:
	if not _is_host():
		return
	if state.order.is_empty():
		sync_members_from_room()
	if state.order.is_empty():
		return
	if state.phase == MatchPhase.Phase.INITIALIZATION:
		state.phase = MatchPhase.Phase.TURN_PLAY
		state.active_uid = state.order.random_uid()
	elif state.phase == MatchPhase.Phase.TURN_PLAY:
		state.active_uid = state.order.next_after(state.active_uid)
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
	state.phase = MatchPhase.Phase.ROUND_RESOLUTION
	if _session != null and _session.match_card_controller != null:
		_session.match_card_controller.end_round()
	_broadcast()
	# Mock resolution beat, then next turn.
	await get_tree().create_timer(0.35).timeout
	if not _is_host() or _session.current_room == null:
		return
	if state.phase != MatchPhase.Phase.ROUND_RESOLUTION:
		return
	state.phase = MatchPhase.Phase.TURN_PLAY
	if not state.active_uid.is_empty():
		state.active_uid = state.order.next_after(state.active_uid)
	elif not state.order.is_empty():
		state.active_uid = state.order.uids[0]
	_broadcast()


func end_game_play() -> void:
	if not _is_host():
		return
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


func _emit_changed() -> void:
	if _session != null:
		_session.match_changed.emit(state)


func _is_host() -> bool:
	return _session != null and _session.is_local_host()
