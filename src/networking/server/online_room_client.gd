class_name OnlineRoomClient
extends Node
## Client-side online create/join/leave against OnlineLobbyRpc.

var _session: RoomSessionNode
var _lobby: OnlineLobbyRpc
var _pending_create := false


func setup(session: RoomSessionNode, lobby: OnlineLobbyRpc) -> void:
	_session = session
	_lobby = lobby
	_lobby.action_failed.connect(_on_action_failed)
	_lobby.public_rooms_received.connect(_on_public_rooms)


func create_room(is_public: bool, max_players: int = 4, room_name: String = "") -> Error:
	if not NetworkModeService.is_central_connected():
		return ERR_CANT_CONNECT
	if PlayerDataStore.data == null:
		return ERR_INVALID_DATA
	_pending_create = true
	var profile := PlayerDataStore.get_profile()
	var avatar := ""
	if profile.avatar_id != null:
		avatar = str(profile.avatar_id)
	_lobby.send_create({
		"uid": PlayerDataStore.data.uid,
		"nickname": profile.nickname,
		"avatar_id": avatar,
		"is_public": is_public,
		"max_players": max_players,
		"name": room_name,
	})
	return OK


func join_room_code(code: String) -> Error:
	if not NetworkModeService.is_central_connected():
		return ERR_CANT_CONNECT
	if PlayerDataStore.data == null:
		return ERR_INVALID_DATA
	var profile := PlayerDataStore.get_profile()
	var avatar := ""
	if profile.avatar_id != null:
		avatar = str(profile.avatar_id)
	_lobby.send_join({
		"code": code.strip_edges().to_upper(),
		"uid": PlayerDataStore.data.uid,
		"nickname": profile.nickname,
		"avatar_id": avatar,
	})
	return OK


func request_public_rooms() -> void:
	if NetworkModeService.is_central_connected():
		_lobby.send_list_request()


func leave_room() -> void:
	if _session.rpc_node == null:
		return
	_session.rpc_node.send_leave_request()
	# Room cleared when leave_acked arrives (keeps central connection).


func _on_action_failed(reason: String) -> void:
	_pending_create = false
	_session.join_failed.emit(reason)
	# Rejoin / BusyBlocker listen to join_failed; only end here if rejoin isn't owning the gate.
	if RoomSession.rejoin == null or not RoomSession.rejoin.is_active():
		BusyBlocker.end("操作失败: %s" % reason)


func _on_public_rooms(rooms: Array) -> void:
	_session.online_rooms_received.emit(rooms)
