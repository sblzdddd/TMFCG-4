class_name RoomHandlers
extends Node
## Host/client room event handlers used by RoomManager.

var _mgr: RoomManagerNode


func setup(manager: RoomManagerNode) -> void:
	_mgr = manager


func on_handshake(peer_id: int, payload: Dictionary) -> void:
	var room: RoomData = _mgr.current_room
	if room == null:
		return
	var uid := str(payload.get("uid", ""))
	var idx := room.find_member_uid(uid)
	if idx >= 0:
		_mgr.presence.cancel(uid)
		room.set_member_online(uid, true, peer_id)
	else:
		if room.is_full():
			_mgr.rpc_node.send_kick(peer_id)
			return
		room.upsert_member(RoomMember.from_dict({
			"uid": uid,
			"nickname": str(payload.get("nickname", "Player")),
			"avatar_id": str(payload.get("avatar_id", "")),
			"peer_id": peer_id,
			"is_online": true,
		}))
	_mgr.broadcast_and_advertise()


func on_leave_requested(peer_id: int) -> void:
	var room: RoomData = _mgr.current_room
	if room == null:
		_mgr.rpc_node.send_leave_ack(peer_id)
		return
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		_mgr.rpc_node.send_leave_ack(peer_id)
		return
	var entry: Dictionary = room.members[idx] as Dictionary
	var uid := str(entry.get("uid", ""))
	var nickname := str(entry.get("nickname", "Player"))
	_mgr.presence.mark_voluntary_leave(uid)
	room.remove_member_uid(uid)
	_mgr.rpc_node.send_leave_ack(peer_id)
	_mgr.rpc_node.broadcast_member_left(nickname, peer_id)
	_mgr.member_left.emit(nickname)
	_mgr.broadcast_and_advertise()


func on_peer_disconnected(peer_id: int) -> void:
	if not ConnectionManager.is_server() or _mgr.current_room == null:
		return
	var room: RoomData = _mgr.current_room
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return
	var uid := str((room.members[idx] as Dictionary).get("uid", ""))
	if _mgr.presence.consume_voluntary_leave(uid):
		return
	room.set_member_online(uid, false)
	_mgr.presence.mark_offline(uid)
	_mgr.broadcast_and_advertise()


func on_grace_expired(uid: String) -> void:
	if _mgr.current_room == null:
		return
	_mgr.current_room.remove_member_uid(uid)
	_mgr.broadcast_and_advertise()


func on_snapshot(snapshot: Dictionary) -> void:
	if _mgr.is_leaving_voluntarily():
		return
	_mgr.current_room = RoomData.from_snapshot(snapshot)
	_mgr.persist_last_room(_mgr.join_address, _mgr.join_port)
	_mgr.room_changed.emit(_mgr.current_room)
	_mgr.ensure_combat_scene()


func apply_profile_update(payload: Dictionary) -> void:
	var room: RoomData = _mgr.current_room
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
	_mgr.broadcast_and_advertise()


func sync_local_profile() -> void:
	if _mgr.current_room == null or PlayerDataStore.data == null:
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
		_mgr.rpc_node.send_profile_update(payload)


func leave_client_after_flush() -> void:
	# Deliver request_leave before closing the WebSocket peer.
	await get_tree().create_timer(0.12).timeout
	if _mgr.current_room != null or ConnectionManager.is_connected_peer():
		_mgr.teardown_local(true)


func kick_member(uid: String) -> void:
	if not ConnectionManager.is_server() or _mgr.current_room == null:
		return
	if uid == _mgr.current_room.host_uid:
		return
	var idx: int = _mgr.current_room.find_member_uid(uid)
	if idx < 0:
		return
	var entry: Dictionary = _mgr.current_room.members[idx] as Dictionary
	var peer_id := int(entry.get("peer_id", 0))
	var nickname := str(entry.get("nickname", "Player"))
	_mgr.presence.cancel(uid)
	_mgr.current_room.remove_member_uid(uid)
	if peer_id > 1:
		_mgr.rpc_node.send_kick(peer_id)
	_mgr.member_kicked.emit(nickname)
	_mgr.broadcast_and_advertise()


func apply_options_patch(patch: Dictionary) -> void:
	var room: RoomData = _mgr.current_room
	if room == null:
		return
	if patch.has("name"):
		room.name = str(patch["name"])
	if patch.has("is_public"):
		room.is_public = bool(patch["is_public"])
	if patch.has("max_players"):
		room.max_players = clampi(int(patch["max_players"]), 2, 4)
	_mgr.broadcast_and_advertise()
