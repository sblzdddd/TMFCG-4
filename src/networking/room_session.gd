class_name RoomSessionNode
extends Node
## Autoload: room lifecycle (create / join / leave) + combat navigation.

signal room_changed(room: RoomData)
signal join_failed(reason: String)
## Host kicked someone (local host only).
signal member_kicked(nickname: String)
## Local peer was kicked.
signal kicked_from_room(room_name: String)
## Someone else left (all remaining peers).
signal member_left(nickname: String)
## Local peer left voluntarily (or dissolved as host).
signal left_room(room_name: String, was_host: bool)
## Host dissolved the room (clients only).
signal room_dissolved(room_name: String)

var current_room: RoomData
var rpc_node: RoomRpc
var presence: RoomPresence
var handlers: RoomHandlers
var rejoin: RoomRejoin
var deck_sync: RoomDeckSync

var join_address: String = ""
var join_port: int = NetConst.GAME_PORT
var _leaving_voluntarily := false


func _ready() -> void:
	RoomBootstrap.setup(self)
	rejoin.call_deferred("try_startup")


func create_room(is_public: bool, max_players: int = 4, room_name: String = "") -> Error:
	var err := ConnectionManager.host(NetConst.GAME_PORT)
	if err != OK:
		return err
	rejoin.reset()
	var host_member := RoomMember.from_local(ConnectionManager.get_unique_id())
	if room_name.strip_edges().is_empty():
		room_name = "%s 的房间" % host_member.nickname
	current_room = RoomData.create_hosted(host_member, room_name, is_public, max_players)
	deck_sync.bind_host_default_source()
	persist_last_room(RoomUtils.local_lan_address(), NetConst.GAME_PORT)
	sync_advertise()
	room_changed.emit(current_room)
	LevelLoader.load_level(NetConst.COMBAT_SCENE)
	return OK


func join_room(address: String, port: int = NetConst.GAME_PORT) -> Error:
	join_address = address.strip_edges()
	join_port = port
	var err := ConnectionManager.join(join_address, join_port)
	if err != OK and not rejoin.is_active():
		join_failed.emit(error_string(err))
	return err


func leave_room() -> void:
	if current_room == null and not ConnectionManager.is_connected_peer():
		return
	_leaving_voluntarily = true
	var room_name := current_room.name if current_room else ""
	var was_host := is_local_host()
	left_room.emit(room_name, was_host)
	if ConnectionManager.is_server():
		dissolve_room()
		return
	if not ConnectionManager.is_connected_peer():
		teardown_local(true)
		return
	rpc_node.send_leave_request()
	handlers.leave_client_after_flush()


func sync_local_profile() -> void:
	handlers.sync_local_profile()


func update_options(patch: Dictionary) -> void:
	if current_room == null:
		return
	if is_local_host():
		handlers.apply_options_patch(patch)
	else:
		rpc_node.send_options_patch(patch)


func set_room_deck(path: String) -> void:
	deck_sync.set_deck_from_path(path)


func get_resolved_deck() -> DeckData:
	return deck_sync.get_resolved_deck() if deck_sync else null


func kick_member(uid: String) -> void:
	handlers.kick_member(uid)


func broadcast_and_advertise() -> void:
	if current_room == null:
		return
	room_changed.emit(current_room)
	if ConnectionManager.is_server():
		rpc_node.broadcast_snapshot(current_room.to_snapshot())
	sync_advertise()


func sync_advertise() -> void:
	if current_room == null or not ConnectionManager.is_server() or not current_room.is_public:
		RoomDiscovery.stop_advertising()
		return
	var payload: Dictionary = RoomDiscovery.build_advertise_payload(current_room)
	if RoomDiscovery.is_advertising():
		RoomDiscovery.update_payload(payload)
	else:
		RoomDiscovery.start_advertising(payload)


func persist_last_room(address: String, port: int) -> void:
	if current_room:
		PlayerDataStore.set_last_room(current_room.code, address, port)


func ensure_combat_scene() -> void:
	if RoomUtils.scene_path(get_tree()) != NetConst.COMBAT_SCENE:
		LevelLoader.load_level(NetConst.COMBAT_SCENE)


func dissolve_room() -> void:
	RoomDiscovery.stop_advertising()
	if ConnectionManager.is_server() and ConnectionManager.is_connected_peer():
		rpc_node.broadcast_room_closed()
		# Deliver notify_room_closed before closing the WebSocket peer.
		await get_tree().create_timer(0.15).timeout
	teardown_local(true)


func teardown_local(go_title: bool) -> void:
	var had_session := current_room != null or ConnectionManager.is_connected_peer()
	_leaving_voluntarily = true
	rejoin.reset()
	presence.clear_all()
	RoomDiscovery.stop_advertising()
	current_room = null
	if deck_sync:
		deck_sync.clear()
	ConnectionManager.leave()
	PlayerDataStore.clear_last_room()
	room_changed.emit(null)
	_leaving_voluntarily = false
	if go_title and had_session and RoomUtils.scene_path(get_tree()) != NetConst.TITLE_SCENE:
		LevelLoader.load_level(NetConst.TITLE_SCENE)


func is_local_host() -> bool:
	return current_room != null and PlayerDataStore.data != null \
		and current_room.host_uid == PlayerDataStore.data.uid


func is_leaving_voluntarily() -> bool:
	return _leaving_voluntarily


func _on_connected_to_host() -> void:
	rejoin.reset()
	var m := RoomMember.from_local(ConnectionManager.get_unique_id())
	rpc_node.send_handshake({"uid": m.uid, "nickname": m.nickname, "avatar_id": m.avatar_id})


func _on_options_from_peer(patch: Dictionary) -> void:
	if ConnectionManager.is_server():
		handlers.apply_options_patch(patch)
