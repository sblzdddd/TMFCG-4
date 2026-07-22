class_name ServerRoomRegistry
extends Node
## Multi-room index on the dedicated server. Routes peer-scoped RPCs to runtimes.

var _rooms: Dictionary = {} # code -> ServerRoomRuntime
var _peer_room: Dictionary = {} # peer_id -> code
var _lobby_rpc: OnlineLobbyRpc
var _room_rpc: RoomRpc


func setup() -> void:
	_room_rpc = RoomSession.rpc_node
	_lobby_rpc = RoomSession.online_lobby_rpc
	if _lobby_rpc == null or _room_rpc == null:
		push_error("ServerRoomRegistry: RPC nodes missing on RoomSession")
		return
	_lobby_rpc.create_requested.connect(_on_create_requested)
	_lobby_rpc.join_requested.connect(_on_join_requested)
	_lobby_rpc.list_requested.connect(_on_list_requested)

	_rewire_room_rpc()
	_rewire_match_rpc()
	_rewire_deck_rpc()
	_rewire_chat()
	ConnectionManager.peer_disconnected.connect(_on_peer_disconnected)


func runtime_for_peer(peer_id: int) -> ServerRoomRuntime:
	var code := str(_peer_room.get(peer_id, ""))
	if code.is_empty():
		return null
	return _rooms.get(code) as ServerRoomRuntime


func broadcast_room_snapshot(runtime: ServerRoomRuntime) -> void:
	if runtime == null or runtime.current_room == null or _room_rpc == null:
		return
	var snapshot := runtime.current_room.to_snapshot()
	for peer_id in runtime.get_member_peer_ids():
		_room_rpc.send_snapshot_to(peer_id, snapshot)


func destroy_runtime(runtime: ServerRoomRuntime) -> void:
	if runtime == null:
		return
	var code := ""
	if runtime.current_room != null:
		code = runtime.current_room.code
	for peer_id in runtime.get_member_peer_ids():
		_peer_room.erase(peer_id)
	if not code.is_empty():
		_rooms.erase(code)
	# Also erase any stale peer mappings pointing at this code.
	var stale: Array = []
	for peer_id in _peer_room:
		if str(_peer_room[peer_id]) == code:
			stale.append(peer_id)
	for peer_id in stale:
		_peer_room.erase(peer_id)
	runtime.destroy()


func _on_create_requested(peer_id: int, payload: Dictionary) -> void:
	if _peer_room.has(peer_id):
		_lobby_rpc.send_action_failed(peer_id, "already in a room")
		return
	var nickname := str(payload.get("nickname", "Player"))
	var room_name := str(payload.get("name", ""))
	if room_name.strip_edges().is_empty():
		room_name = "%s 的房间" % nickname
	var host_member := RoomMember.from_dict({
		"uid": str(payload.get("uid", "")),
		"nickname": nickname,
		"avatar_id": str(payload.get("avatar_id", "")),
		"peer_id": peer_id,
		"is_online": true,
	})
	if host_member.uid.is_empty():
		_lobby_rpc.send_action_failed(peer_id, "missing uid")
		return
	var runtime := _spawn_runtime()
	runtime.current_room = RoomData.create_hosted(
		host_member,
		room_name,
		bool(payload.get("is_public", false)),
		int(payload.get("max_players", 4)),
	)
	runtime.deck_sync.bind_host_default_source()
	_rooms[runtime.current_room.code] = runtime
	_peer_room[peer_id] = runtime.current_room.code
	runtime.broadcast_and_advertise()


func _on_join_requested(peer_id: int, payload: Dictionary) -> void:
	if _peer_room.has(peer_id):
		_lobby_rpc.send_action_failed(peer_id, "already in a room")
		return
	var code := str(payload.get("code", "")).strip_edges().to_upper()
	var runtime: ServerRoomRuntime = _rooms.get(code) as ServerRoomRuntime
	if runtime == null or runtime.current_room == null:
		_lobby_rpc.send_action_failed(peer_id, "room not found")
		return
	_peer_room[peer_id] = code
	runtime.handlers.on_handshake(peer_id, payload)
	if runtime.current_room.find_member_peer(peer_id) < 0:
		_peer_room.erase(peer_id)


func _on_list_requested(peer_id: int) -> void:
	var list: Array = []
	for code in _rooms:
		var runtime: ServerRoomRuntime = _rooms[code]
		if runtime == null or runtime.current_room == null:
			continue
		var room: RoomData = runtime.current_room
		if not room.is_public:
			continue
		list.append({
			"code": room.code,
			"name": room.name,
			"players": room.member_count(),
			"max": room.max_players,
		})
	_lobby_rpc.send_public_rooms(peer_id, list)


func _on_peer_disconnected(peer_id: int) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime == null:
		return
	runtime.handlers.on_peer_disconnected(peer_id)


func _spawn_runtime() -> ServerRoomRuntime:
	var runtime := ServerRoomRuntime.new()
	runtime.name = "Room_%d" % Time.get_ticks_msec()
	add_child(runtime)
	runtime.setup(self, _room_rpc)
	return runtime


func _rewire_room_rpc() -> void:
	_room_rpc.handshake_received.connect(_on_handshake)
	_room_rpc.leave_requested.connect(_on_leave_requested)
	_room_rpc.options_patch_received.connect(_on_options_patch)
	_room_rpc.kick_requested.connect(_on_kick_requested)
	_room_rpc.profile_update_received.connect(_on_profile_update)


func _rewire_match_rpc() -> void:
	var match_rpc: MatchRpc = RoomSession.match_rpc
	var card_rpc: MatchCardRpc = RoomSession.match_card_rpc
	if card_rpc != null:
		var card_ctrl: MatchCardController = RoomSession.match_card_controller
		if card_ctrl != null:
			if card_rpc.play_requested.is_connected(card_ctrl.handle_play_request):
				card_rpc.play_requested.disconnect(card_ctrl.handle_play_request)
			if card_rpc.pass_requested.is_connected(card_ctrl.handle_pass_request):
				card_rpc.pass_requested.disconnect(card_ctrl.handle_pass_request)
		card_rpc.play_requested.connect(_on_play_requested)
		card_rpc.pass_requested.connect(_on_pass_requested)
	if match_rpc != null:
		match_rpc.host_command_requested.connect(_on_host_command)


func _rewire_deck_rpc() -> void:
	var deck_rpc: RoomDeckRpc = RoomSession.deck_rpc
	if deck_rpc == null:
		return
	var deck_sync: RoomDeckSync = RoomSession.deck_sync
	if deck_sync != null:
		if deck_rpc.deck_tres_requested.is_connected(deck_sync._on_deck_tres_requested):
			deck_rpc.deck_tres_requested.disconnect(deck_sync._on_deck_tres_requested)
	deck_rpc.deck_tres_requested.connect(_on_deck_tres_requested)
	deck_rpc.deck_set_requested.connect(_on_deck_set_requested)


func _rewire_chat() -> void:
	if ChatService.chat_rpc == null:
		return
	if ChatService.chat_rpc.chat_submitted.is_connected(ChatService.chat_handlers.on_chat_submitted):
		ChatService.chat_rpc.chat_submitted.disconnect(ChatService.chat_handlers.on_chat_submitted)
	ChatService.chat_rpc.chat_submitted.connect(_on_chat_submitted)


func _on_handshake(peer_id: int, payload: Dictionary) -> void:
	var code := str(payload.get("room_code", "")).strip_edges().to_upper()
	if code.is_empty():
		code = str(_peer_room.get(peer_id, ""))
	var runtime: ServerRoomRuntime = _rooms.get(code) as ServerRoomRuntime
	if runtime == null:
		_room_rpc.send_kick(peer_id)
		return
	_peer_room[peer_id] = code
	runtime.handlers.on_handshake(peer_id, payload)


func _on_leave_requested(peer_id: int) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime == null:
		_room_rpc.send_leave_ack(peer_id)
		return
	runtime.handlers.on_leave_requested(peer_id)
	_peer_room.erase(peer_id)


func _on_options_patch(peer_id: int, patch: Dictionary) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime:
		runtime.handlers.apply_options_patch_from_peer(peer_id, patch)


func _on_kick_requested(peer_id: int, target_uid: String) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime:
		runtime.handlers.on_kick_requested(peer_id, target_uid)


func _on_profile_update(payload: Dictionary) -> void:
	var uid := str(payload.get("uid", ""))
	for code in _rooms:
		var runtime: ServerRoomRuntime = _rooms[code]
		if runtime and runtime.current_room and runtime.current_room.find_member_uid(uid) >= 0:
			runtime.handlers.apply_profile_update(payload)
			return


func _on_play_requested(peer_id: int, card_ids: Array) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime and runtime.match_card_controller:
		runtime.match_card_controller.handle_play_request(peer_id, card_ids)
		return
	print(
		"[MatchPlayTrace][server.route_failed][%.3f] reason=room_runtime_missing peer=%d ids=%s"
		% [
			Time.get_unix_time_from_system(),
			peer_id,
			JSON.stringify(card_ids),
		]
	)


func _on_pass_requested(peer_id: int) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime and runtime.match_card_controller:
		runtime.match_card_controller.handle_pass_request(peer_id)


func _on_host_command(peer_id: int, command: String, args: Dictionary) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime == null or runtime.handlers == null:
		return
	if not runtime.handlers.is_host_peer(peer_id):
		return
	if runtime.match_controller:
		runtime.match_controller.execute_host_command(command, args)


func _on_deck_tres_requested(peer_id: int) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime and runtime.deck_sync:
		runtime.deck_sync.handle_deck_tres_request(peer_id)


func _on_deck_set_requested(peer_id: int, profile: Dictionary) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime and runtime.deck_sync:
		runtime.deck_sync.apply_deck_profile_from_peer(peer_id, profile)


func _on_chat_submitted(peer_id: int, content: String) -> void:
	var runtime := runtime_for_peer(peer_id)
	if runtime == null or runtime.current_room == null:
		return
	var room: RoomData = runtime.current_room
	var trimmed := content.strip_edges()
	if trimmed.is_empty() or trimmed.length() > ChatHandlers.MAX_CHAT_LENGTH:
		return
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return
	var entry: Dictionary = room.members[idx] as Dictionary
	var payload := {
		"uid": str(entry.get("uid", "")),
		"nickname": str(entry.get("nickname", "Player")),
		"avatar_id": str(entry.get("avatar_id", "")),
		"content": trimmed,
	}
	for member_peer in runtime.get_member_peer_ids():
		ChatService.chat_rpc.deliver_chat.rpc_id(member_peer, payload)
