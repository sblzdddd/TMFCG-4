class_name OnlineLobbyRpc
extends Node
## Lobby RPCs: create / join / list public rooms on the dedicated server.

signal create_requested(peer_id: int, payload: Dictionary)
signal join_requested(peer_id: int, payload: Dictionary)
signal list_requested(peer_id: int)
signal public_rooms_received(rooms: Array)
signal action_failed(reason: String)


@rpc("any_peer", "reliable")
func request_create_room(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	create_requested.emit(multiplayer.get_remote_sender_id(), payload)


@rpc("any_peer", "reliable")
func request_join_room(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	join_requested.emit(multiplayer.get_remote_sender_id(), payload)


@rpc("any_peer", "reliable")
func request_public_rooms() -> void:
	if not multiplayer.is_server():
		return
	list_requested.emit(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable", "call_remote")
func deliver_public_rooms(rooms: Array) -> void:
	public_rooms_received.emit(rooms)


@rpc("authority", "reliable", "call_remote")
func notify_action_failed(reason: String) -> void:
	action_failed.emit(reason)


func send_create(payload: Dictionary) -> void:
	request_create_room.rpc_id(1, payload)


func send_join(payload: Dictionary) -> void:
	request_join_room.rpc_id(1, payload)


func send_list_request() -> void:
	request_public_rooms.rpc_id(1)


func send_public_rooms(peer_id: int, rooms: Array) -> void:
	if not _can_send_to(peer_id):
		return
	deliver_public_rooms.rpc_id(peer_id, rooms)


func send_action_failed(peer_id: int, reason: String) -> void:
	if not _can_send_to(peer_id):
		return
	notify_action_failed.rpc_id(peer_id, reason)


func _can_send_to(peer_id: int) -> bool:
	if peer_id <= 0 or not multiplayer.has_multiplayer_peer():
		return false
	if peer_id == multiplayer.get_unique_id():
		return false
	for id in multiplayer.get_peers():
		if int(id) == peer_id:
			return true
	return false
