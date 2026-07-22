class_name ServerRoomRuntime
extends Node
## One room's authoritative state on the dedicated server (session-like façade).

signal room_changed(room: RoomData)
@warning_ignore("unused_signal")
signal match_changed(state: MatchRuntimeState)
@warning_ignore("unused_signal")
signal card_state_changed(state: GameState)
@warning_ignore("unused_signal")
signal cards_drawn(card_ids: Array[String])
@warning_ignore("unused_signal")
signal member_left(nickname: String)
@warning_ignore("unused_signal")
signal member_kicked(nickname: String)

var current_room: RoomData
var rpc_node: RoomRpc
var presence: RoomPresence
var handlers: RoomHandlers
var deck_sync: RoomDeckSync
var match_controller: MatchController
var match_card_controller: MatchCardController

var join_address: String = ""
var join_port: int = NetConst.GAME_PORT
var _leaving_voluntarily := false
var _registry: ServerRoomRegistry


func setup(registry: ServerRoomRegistry, shared_rpc: RoomRpc) -> void:
	_registry = registry
	rpc_node = shared_rpc

	presence = RoomPresence.new()
	presence.name = "RoomPresence"
	add_child(presence)

	handlers = RoomHandlers.new()
	handlers.name = "RoomHandlers"
	add_child(handlers)
	handlers.setup(self, rpc_node, presence)

	deck_sync = RoomDeckSync.new()
	deck_sync.name = "RoomDeckSync"
	add_child(deck_sync)
	deck_sync.setup(self, RoomSession.deck_rpc, false)

	match_controller = MatchController.new()
	match_controller.name = "MatchController"
	add_child(match_controller)
	match_controller.setup(self, RoomSession.match_rpc, false)

	match_card_controller = MatchCardController.new()
	match_card_controller.name = "MatchCardController"
	add_child(match_card_controller)
	match_card_controller.setup(self, RoomSession.match_card_rpc, false)

	presence.member_grace_expired.connect(handlers.on_grace_expired)


func is_local_host() -> bool:
	return false


func is_leaving_voluntarily() -> bool:
	return _leaving_voluntarily


func broadcast_and_advertise() -> void:
	if current_room == null:
		return
	room_changed.emit(current_room)
	_registry.broadcast_room_snapshot(self)


func sync_advertise() -> void:
	pass


func persist_last_room(_address: String, _port: int) -> void:
	pass


func ensure_room_scene() -> void:
	pass


func get_resolved_deck() -> DeckData:
	return deck_sync.get_resolved_deck() if deck_sync else null


func get_member_peer_ids(except_peer_id: int = 0) -> Array[int]:
	var ids: Array[int] = []
	if current_room == null:
		return ids
	var live_peers: Dictionary = {}
	for peer_id in multiplayer.get_peers():
		live_peers[int(peer_id)] = true
	for member in current_room.get_members():
		if not member.is_online:
			continue
		if member.peer_id <= 0 or member.peer_id == except_peer_id:
			continue
		# Skip stale peer ids left from previous connections (avoids WSL STATE_OPEN errors).
		if not live_peers.has(member.peer_id):
			continue
		ids.append(member.peer_id)
	return ids


func on_member_fully_removed(uid: String) -> void:
	transfer_host_if_needed(uid)
	broadcast_and_advertise()
	if current_room != null and current_room.member_count() <= 0:
		_registry.destroy_runtime(self)


func transfer_host_if_needed(removed_uid: String) -> void:
	if current_room == null:
		return
	if current_room.host_uid != removed_uid:
		return
	for member in current_room.get_members():
		if member.uid != removed_uid:
			current_room.host_uid = member.uid
			return
	current_room.host_uid = ""


func destroy() -> void:
	if match_controller:
		match_controller.clear()
	if match_card_controller:
		match_card_controller.clear()
	if deck_sync:
		deck_sync.clear()
	if presence:
		presence.clear_all()
	current_room = null
	queue_free()
