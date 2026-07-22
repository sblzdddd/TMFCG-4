class_name RoomSessionNode
extends Node
## Autoload: room lifecycle (create / join / leave) against a dedicated server.


signal room_changed(room: RoomData)
signal match_changed(state: MatchRuntimeState)
signal card_state_changed(state: GameState)
signal cards_drawn(card_ids: Array[String])
signal join_failed(reason: String)
signal member_kicked(nickname: String)
signal kicked_from_room(room_name: String)
signal member_left(nickname: String)
signal left_room(room_name: String, was_host: bool)
signal room_dissolved(room_name: String)
signal online_rooms_received(rooms: Array)

var current_room: RoomData
var rpc_node: RoomRpc
var match_rpc: MatchRpc
var match_card_rpc: MatchCardRpc
var deck_rpc: RoomDeckRpc
var online_lobby_rpc: OnlineLobbyRpc
var presence: RoomPresence
var handlers: RoomHandlers
var rejoin: RoomRejoin
var deck_sync: RoomDeckSync
var match_controller: MatchController
var match_card_controller: MatchCardController
var online_client: OnlineRoomClient

var join_address: String = ""
var join_port: int = NetConst.GAME_PORT
var _leaving_voluntarily := false


func _ready() -> void:
	RoomBootstrap.setup(self)
	if not NetEnv.is_dedicated_server():
		rejoin.call_deferred("try_startup")


func create_room(is_public: bool, max_players: int = 4, room_name: String = "") -> Error:
	if not NetworkModeService.is_central_connected():
		return ERR_CANT_CONNECT
	return online_client.create_room(is_public, max_players, room_name)


func join_room(address: String, port: int = NetConst.GAME_PORT) -> Error:
	## Transport join used by NetworkModeService; room membership goes through lobby.
	join_address = address.strip_edges()
	join_port = port
	var err := ConnectionManager.join(join_address, join_port)
	if err != OK and not rejoin.is_active():
		join_failed.emit(error_string(err))
	return err


func join_room_code(code: String) -> Error:
	if not NetworkModeService.is_central_connected():
		return ERR_CANT_CONNECT
	return online_client.join_room_code(code)


func leave_room() -> void:
	if current_room == null and not ConnectionManager.is_connected_peer():
		return
	_leaving_voluntarily = true
	var room_name := current_room.name if current_room else ""
	var was_host := is_local_host()
	left_room.emit(room_name, was_host)
	if NetworkModeService.is_central_connected() and current_room != null:
		online_client.leave_room()
		return
	if not ConnectionManager.is_connected_peer():
		teardown_room_keep_connection(true)
		return
	rpc_node.send_leave_request()
	handlers.leave_online_after_flush()


func sync_local_profile() -> void:
	handlers.sync_local_profile()


func update_options(patch: Dictionary) -> void:
	if current_room == null:
		return
	if ConnectionManager.is_server():
		handlers.apply_options_patch(patch)
	else:
		rpc_node.send_options_patch(patch)


func set_room_deck(path: String) -> void:
	deck_sync.set_deck_from_path(path)


func get_resolved_deck() -> DeckData:
	return deck_sync.get_resolved_deck() if deck_sync else null


func kick_member(uid: String) -> void:
	if ConnectionManager.is_server():
		handlers.kick_member(uid)
	elif is_local_host():
		rpc_node.send_kick_request(uid)


func broadcast_and_advertise() -> void:
	if current_room == null:
		return
	room_changed.emit(current_room)
	if ConnectionManager.is_server():
		rpc_node.broadcast_snapshot(current_room.to_snapshot(), get_member_peer_ids())


func get_member_peer_ids(except_peer_id: int = 0) -> Array[int]:
	var ids: Array[int] = []
	if current_room == null:
		return ids
	var live_peers: Dictionary = {}
	if multiplayer.has_multiplayer_peer():
		for peer_id in multiplayer.get_peers():
			live_peers[int(peer_id)] = true
	for member in current_room.get_members():
		if member.peer_id <= 0 or member.peer_id == except_peer_id:
			continue
		if not live_peers.is_empty() and not live_peers.has(member.peer_id):
			continue
		ids.append(member.peer_id)
	return ids


func persist_last_room(address: String, port: int) -> void:
	if current_room:
		PlayerDataStore.set_last_room(current_room.code, address, port)


func ensure_room_scene() -> void:
	if RoomUtils.scene_path(get_tree()) != NetConst.ROOM_SCENE:
		LevelLoader.load_level(NetConst.ROOM_SCENE)


func teardown_local(go_title: bool) -> void:
	## Full disconnect (rare); prefer teardown_room_keep_connection for online leave.
	var had_session := current_room != null or ConnectionManager.is_connected_peer()
	_leaving_voluntarily = true
	rejoin.reset()
	presence.clear_all()
	current_room = null
	if deck_sync:
		deck_sync.clear()
	if match_controller:
		match_controller.clear()
	if match_card_controller:
		match_card_controller.clear()
	ConnectionManager.leave()
	PlayerDataStore.clear_last_room()
	room_changed.emit(null)
	_leaving_voluntarily = false
	if go_title and had_session and RoomUtils.scene_path(get_tree()) != NetConst.TITLE_SCENE:
		LevelLoader.load_level(NetConst.TITLE_SCENE)


func teardown_room_keep_connection(go_title: bool) -> void:
	var had_room := current_room != null
	_leaving_voluntarily = true
	rejoin.reset()
	presence.clear_all()
	current_room = null
	if deck_sync:
		deck_sync.clear()
	if match_controller:
		match_controller.clear()
	if match_card_controller:
		match_card_controller.clear()
	PlayerDataStore.clear_last_room()
	room_changed.emit(null)
	_leaving_voluntarily = false
	if go_title and had_room and RoomUtils.scene_path(get_tree()) != NetConst.TITLE_SCENE:
		LevelLoader.load_level(NetConst.TITLE_SCENE)


func is_local_host() -> bool:
	return current_room != null and PlayerDataStore.data != null \
		and current_room.host_uid == PlayerDataStore.data.uid


func is_leaving_voluntarily() -> bool:
	return _leaving_voluntarily


func _on_connected_to_host() -> void:
	# Central connection only; membership goes through OnlineLobbyRpc.
	pass


func _on_options_from_peer(peer_id: int, patch: Dictionary) -> void:
	if ConnectionManager.is_server():
		handlers.apply_options_patch_from_peer(peer_id, patch)


func _on_leave_acked() -> void:
	teardown_room_keep_connection(true)
