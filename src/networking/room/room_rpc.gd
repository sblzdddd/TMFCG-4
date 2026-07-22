class_name RoomRpc
extends Node
## Thin RPC façade for room handshake / sync / leave / kick.

signal handshake_received(peer_id: int, payload: Dictionary)
signal leave_requested(peer_id: int)
signal room_snapshot_received(snapshot: Dictionary)
signal room_closed_received()
signal options_patch_received(peer_id: int, patch: Dictionary)
signal kick_requested(peer_id: int, target_uid: String)
signal profile_update_received(payload: Dictionary)
signal kick_received()
signal leave_acked()
signal member_left_received(nickname: String)


@rpc("any_peer", "reliable")
func submit_handshake(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	handshake_received.emit(multiplayer.get_remote_sender_id(), payload)


@rpc("any_peer", "reliable")
func request_leave() -> void:
	if not multiplayer.is_server():
		return
	leave_requested.emit(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable", "call_remote")
func apply_room_snapshot(snapshot: Dictionary) -> void:
	room_snapshot_received.emit(snapshot)


@rpc("authority", "reliable", "call_remote")
func notify_room_closed() -> void:
	room_closed_received.emit()


@rpc("any_peer", "reliable")
func submit_options_patch(patch: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	options_patch_received.emit(multiplayer.get_remote_sender_id(), patch)


@rpc("any_peer", "reliable")
func request_kick(target_uid: String) -> void:
	if not multiplayer.is_server():
		return
	kick_requested.emit(multiplayer.get_remote_sender_id(), target_uid)


@rpc("authority", "reliable", "call_remote")
func notify_kicked() -> void:
	kick_received.emit()


@rpc("any_peer", "reliable")
func submit_profile_update(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	profile_update_received.emit(payload)


@rpc("authority", "reliable", "call_remote")
func ack_leave() -> void:
	leave_acked.emit()


@rpc("authority", "reliable", "call_remote")
func notify_member_left(nickname: String) -> void:
	member_left_received.emit(nickname)


func send_handshake(payload: Dictionary) -> void:
	submit_handshake.rpc_id(1, payload)


func send_leave_request() -> void:
	request_leave.rpc_id(1)


func send_profile_update(payload: Dictionary) -> void:
	if multiplayer.is_server():
		profile_update_received.emit(payload)
	else:
		submit_profile_update.rpc_id(1, payload)


func broadcast_snapshot(snapshot: Dictionary, peer_ids: Array = []) -> void:
	if peer_ids.is_empty():
		if NetEnv.is_dedicated_server():
			return
		apply_room_snapshot.rpc(snapshot)
		return
	for peer_id in peer_ids:
		apply_room_snapshot.rpc_id(int(peer_id), snapshot)


func send_snapshot_to(peer_id: int, snapshot: Dictionary) -> void:
	if not _can_send_to(peer_id):
		return
	apply_room_snapshot.rpc_id(peer_id, snapshot)


func broadcast_room_closed() -> void:
	notify_room_closed.rpc()


func send_kick(peer_id: int) -> void:
	if not _can_send_to(peer_id):
		return
	notify_kicked.rpc_id(peer_id)


func send_leave_ack(peer_id: int) -> void:
	if not _can_send_to(peer_id):
		return
	ack_leave.rpc_id(peer_id)


func broadcast_member_left(nickname: String, except_peer_id: int = 0) -> void:
	## Broadcast to all multiplayer peers (local listen-server). Prefer
	## [method broadcast_member_left_to] when scoping to one room.
	if NetEnv.is_dedicated_server():
		return
	for peer_id in multiplayer.get_peers():
		if int(peer_id) == except_peer_id:
			continue
		notify_member_left.rpc_id(int(peer_id), nickname)


func broadcast_member_left_to(
	nickname: String,
	peer_ids: Array,
	except_peer_id: int = 0,
) -> void:
	for peer_id in peer_ids:
		if int(peer_id) == except_peer_id:
			continue
		if not _can_send_to(int(peer_id)):
			continue
		notify_member_left.rpc_id(int(peer_id), nickname)


func send_options_patch(patch: Dictionary) -> void:
	if multiplayer.is_server():
		options_patch_received.emit(multiplayer.get_unique_id(), patch)
	else:
		submit_options_patch.rpc_id(1, patch)


func send_kick_request(target_uid: String) -> void:
	if multiplayer.is_server():
		kick_requested.emit(multiplayer.get_unique_id(), target_uid)
	else:
		request_kick.rpc_id(1, target_uid)


func _can_send_to(peer_id: int) -> bool:
	if peer_id <= 0 or not multiplayer.has_multiplayer_peer():
		return false
	if peer_id == multiplayer.get_unique_id():
		return false
	for id in multiplayer.get_peers():
		if int(id) == peer_id:
			return true
	return false
