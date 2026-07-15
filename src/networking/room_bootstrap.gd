class_name RoomBootstrap
extends RefCounted
## Spawns RoomManager children and wires connection/RPC signals.


static func setup(mgr: RoomManagerNode) -> void:
	var discovery := LanDiscovery.new()
	discovery.name = "LanDiscovery"
	mgr.add_child(discovery)
	mgr.discovery = discovery

	var rpc_node := RoomRpc.new()
	rpc_node.name = "RoomRpc"
	mgr.add_child(rpc_node)
	mgr.rpc_node = rpc_node

	var presence := RoomPresence.new()
	presence.name = "RoomPresence"
	mgr.add_child(presence)
	mgr.presence = presence

	var handlers := RoomHandlers.new()
	handlers.name = "RoomHandlers"
	mgr.add_child(handlers)
	mgr.handlers = handlers
	handlers.setup(mgr)

	var rejoin := RoomRejoin.new()
	rejoin.name = "RoomRejoin"
	mgr.add_child(rejoin)
	mgr.rejoin = rejoin
	rejoin.setup(mgr)

	_wire(mgr)


static func _wire(mgr: RoomManagerNode) -> void:
	ConnectionManager.connected_to_host.connect(mgr._on_connected_to_host)
	ConnectionManager.peer_disconnected.connect(mgr.handlers.on_peer_disconnected)
	ConnectionManager.server_disconnected.connect(mgr.rejoin.on_server_disconnected)
	ConnectionManager.connection_failed.connect(mgr.rejoin.on_connection_failed)
	mgr.discovery.rooms_updated.connect(
		func(r: Array[Dictionary]) -> void: mgr.rooms_discovered.emit(r)
	)
	mgr.rpc_node.handshake_received.connect(mgr.handlers.on_handshake)
	mgr.rpc_node.leave_requested.connect(mgr.handlers.on_leave_requested)
	mgr.rpc_node.room_snapshot_received.connect(mgr.handlers.on_snapshot)
	mgr.rpc_node.room_closed_received.connect(_on_room_closed.bind(mgr))
	mgr.rpc_node.options_patch_received.connect(mgr._on_options_from_peer)
	mgr.rpc_node.profile_update_received.connect(mgr.handlers.apply_profile_update)
	mgr.rpc_node.kick_received.connect(_on_kick_received.bind(mgr))
	mgr.rpc_node.leave_acked.connect(func() -> void: mgr.teardown_local(true))
	mgr.rpc_node.member_left_received.connect(
		func(nickname: String) -> void: mgr.member_left.emit(nickname)
	)
	mgr.presence.member_grace_expired.connect(mgr.handlers.on_grace_expired)
	PlayerDataStore.data_changed.connect(
		func(_d: PlayerData) -> void: mgr.handlers.sync_local_profile()
	)


static func _on_room_closed(mgr: RoomManagerNode) -> void:
	var room_name := mgr.current_room.name if mgr.current_room else ""
	mgr.room_dissolved.emit(room_name)
	mgr.teardown_local(true)


static func _on_kick_received(mgr: RoomManagerNode) -> void:
	var room_name := mgr.current_room.name if mgr.current_room else ""
	mgr.kicked_from_room.emit(room_name)
	mgr.teardown_local(true)
