class_name RoomHandlers
extends Node
## Host/client room event handlers used by RoomSession / ServerRoomRuntime.

var _session: Node
var _rpc: RoomRpc
var _presence: RoomPresence


func setup(session: Node, room_rpc: RoomRpc, presence: RoomPresence) -> void:
	_session = session
	_rpc = room_rpc
	_presence = presence


func on_handshake(peer_id: int, payload: Dictionary) -> void:
	var room: RoomData = _session.current_room
	if room == null:
		return
	var uid := str(payload.get("uid", ""))
	var idx := room.find_member_uid(uid)
	if idx >= 0:
		_presence.cancel(uid)
		room.set_member_online(uid, true, peer_id)
	else:
		var match_ctrl: MatchController = _session.match_controller
		if match_ctrl != null and not match_ctrl.accepts_new_joins():
			_rpc.send_kick(peer_id)
			return
		if room.is_full():
			_rpc.send_kick(peer_id)
			return
		room.upsert_member(RoomMember.from_dict({
			"uid": uid,
			"nickname": str(payload.get("nickname", "Player")),
			"avatar_id": str(payload.get("avatar_id", "")),
			"peer_id": peer_id,
			"is_online": true,
		}))
	_session.broadcast_and_advertise()
	# New peers need the current match snapshot (room snapshot alone has no order/phase).
	if ConnectionManager.is_server() and _session.match_controller != null:
		_session.match_controller.broadcast_state()
	if ConnectionManager.is_server() and _session.match_card_controller != null:
		_session.match_card_controller.send_state_to(peer_id, uid)


func on_leave_requested(peer_id: int) -> void:
	var room: RoomData = _session.current_room
	if room == null:
		_rpc.send_leave_ack(peer_id)
		return
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		_rpc.send_leave_ack(peer_id)
		return
	var entry: Dictionary = room.members[idx] as Dictionary
	var uid := str(entry.get("uid", ""))
	var nickname := str(entry.get("nickname", "Player"))
	_presence.mark_voluntary_leave(uid)
	room.remove_member_uid(uid)
	_rpc.send_leave_ack(peer_id)
	var peers: Array = []
	if _session.has_method("get_member_peer_ids"):
		peers = _session.get_member_peer_ids()
	if peers.is_empty():
		_rpc.broadcast_member_left(nickname, peer_id)
	else:
		_rpc.broadcast_member_left_to(nickname, peers, peer_id)
	_session.member_left.emit(nickname)
	if _session.has_method("on_member_fully_removed"):
		_session.on_member_fully_removed(uid)
	else:
		_session.broadcast_and_advertise()


func on_grace_expired(uid: String) -> void:
	if _session.current_room == null:
		return
	_session.current_room.remove_member_uid(uid)
	if _session.has_method("on_member_fully_removed"):
		_session.on_member_fully_removed(uid)
	else:
		_session.broadcast_and_advertise()


func on_peer_disconnected(peer_id: int) -> void:
	if not ConnectionManager.is_server() or _session.current_room == null:
		return
	var room: RoomData = _session.current_room
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return
	var uid := str((room.members[idx] as Dictionary).get("uid", ""))
	if _presence.consume_voluntary_leave(uid):
		return
	room.set_member_online(uid, false)
	_presence.mark_offline(uid)
	_session.broadcast_and_advertise()


func on_snapshot(snapshot: Dictionary) -> void:
	if _session.is_leaving_voluntarily():
		return
	_session.current_room = RoomData.from_snapshot(snapshot)
	if SettingsDataStore.data != null:
		_session.persist_last_room(
			SettingsDataStore.data.server_address,
			SettingsDataStore.data.server_port,
		)
	_session.room_changed.emit(_session.current_room)
	_session.ensure_room_scene()


func apply_profile_update(payload: Dictionary) -> void:
	var room: RoomData = _session.current_room
	if room == null:
		return
	var uid := str(payload.get("uid", ""))
	var idx: int = room.find_member_uid(uid)
	if idx < 0:
		return
	var entry: Dictionary = (room.members[idx] as Dictionary).duplicate()
	if payload.has("nickname"):
		entry["nickname"] = str(payload["nickname"])
	if payload.has("avatar_id"):
		entry["avatar_id"] = str(payload["avatar_id"])
	room.members[idx] = entry
	_session.broadcast_and_advertise()


func sync_local_profile() -> void:
	if _session.current_room == null or PlayerDataStore.data == null:
		return
	var profile := PlayerDataStore.get_profile()
	var avatar := ""
	if profile.avatar_id != null:
		avatar = str(profile.avatar_id)
	var payload := {
		"uid": PlayerDataStore.data.uid,
		"nickname": profile.nickname,
		"avatar_id": avatar,
	}
	if ConnectionManager.is_server():
		apply_profile_update(payload)
	else:
		_rpc.send_profile_update(payload)


func leave_online_after_flush() -> void:
	await get_tree().create_timer(0.12).timeout
	if _session.current_room != null:
		_session.teardown_room_keep_connection(true)


func on_kick_requested(peer_id: int, target_uid: String) -> void:
	if not ConnectionManager.is_server() or _session.current_room == null:
		return
	if not _is_host_peer(peer_id):
		return
	kick_member(target_uid)


func kick_member(uid: String) -> void:
	if not ConnectionManager.is_server() or _session.current_room == null:
		return
	if uid == _session.current_room.host_uid:
		return
	var idx: int = _session.current_room.find_member_uid(uid)
	if idx < 0:
		return
	var entry: Dictionary = _session.current_room.members[idx] as Dictionary
	var peer_id := int(entry.get("peer_id", 0))
	var nickname := str(entry.get("nickname", "Player"))
	_presence.cancel(uid)
	_session.current_room.remove_member_uid(uid)
	if peer_id > 0 and peer_id != multiplayer.get_unique_id():
		_rpc.send_kick(peer_id)
	_session.member_kicked.emit(nickname)
	_session.broadcast_and_advertise()


func apply_options_patch_from_peer(peer_id: int, patch: Dictionary) -> void:
	if not _is_host_peer(peer_id):
		return
	apply_options_patch(patch)


func apply_options_patch(patch: Dictionary) -> void:
	var room: RoomData = _session.current_room
	if room == null:
		return
	if patch.has("name"):
		room.name = str(patch["name"])
	if patch.has("is_public"):
		room.is_public = bool(patch["is_public"])
	if patch.has("max_players"):
		room.max_players = clampi(int(patch["max_players"]), 2, 4)
	if patch.has("turn_countdown_sec"):
		room.turn_countdown_sec = clampi(int(patch["turn_countdown_sec"]), 5, 45)
	_session.broadcast_and_advertise()


func is_host_peer(peer_id: int) -> bool:
	return _is_host_peer(peer_id)


func _is_host_peer(peer_id: int) -> bool:
	var room: RoomData = _session.current_room
	if room == null:
		return false
	# Local listen-server host is peer 1 and host_uid.
	if peer_id == multiplayer.get_unique_id() and _session.is_local_host():
		return true
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return false
	return str((room.members[idx] as Dictionary).get("uid", "")) == room.host_uid

