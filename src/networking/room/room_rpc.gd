class_name RoomRpc
extends Node
## Thin RPC façade for room handshake / sync / leave / kick.

signal handshake_received(peer_id: int, payload: Dictionary)
signal leave_requested(peer_id: int)
signal room_snapshot_received(snapshot: Dictionary)
signal room_closed_received()
signal options_patch_received(patch: Dictionary)
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
	options_patch_received.emit(patch)


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


func broadcast_snapshot(snapshot: Dictionary) -> void:
	apply_room_snapshot.rpc(snapshot)


func send_snapshot_to(peer_id: int, snapshot: Dictionary) -> void:
	apply_room_snapshot.rpc_id(peer_id, snapshot)


func broadcast_room_closed() -> void:
	notify_room_closed.rpc()


func send_kick(peer_id: int) -> void:
	notify_kicked.rpc_id(peer_id)


func send_leave_ack(peer_id: int) -> void:
	ack_leave.rpc_id(peer_id)


func broadcast_member_left(nickname: String, except_peer_id: int = 0) -> void:
	for peer_id in multiplayer.get_peers():
		if peer_id == except_peer_id:
			continue
		notify_member_left.rpc_id(peer_id, nickname)


func send_options_patch(patch: Dictionary) -> void:
	if multiplayer.is_server():
		options_patch_received.emit(patch)
	else:
		submit_options_patch.rpc_id(1, patch)
