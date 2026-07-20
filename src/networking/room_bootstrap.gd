class_name RoomBootstrap
extends RefCounted
## Spawns RoomSession children and wires connection/RPC signals.


static func setup(session: RoomSessionNode) -> void:
	var rpc_node := RoomRpc.new()
	rpc_node.name = "RoomRpc"
	session.add_child(rpc_node)
	session.rpc_node = rpc_node

	var presence := RoomPresence.new()
	presence.name = "RoomPresence"
	session.add_child(presence)
	session.presence = presence

	var handlers := RoomHandlers.new()
	handlers.name = "RoomHandlers"
	session.add_child(handlers)
	session.handlers = handlers
	handlers.setup(session, rpc_node, presence)

	var rejoin := RoomRejoin.new()
	rejoin.name = "RoomRejoin"
	session.add_child(rejoin)
	session.rejoin = rejoin
	rejoin.setup(session)

	var deck_sync := RoomDeckSync.new()
	deck_sync.name = "RoomDeckSync"
	session.add_child(deck_sync)
	session.deck_sync = deck_sync
	deck_sync.setup(session)

	var match_controller := MatchController.new()
	match_controller.name = "MatchController"
	session.add_child(match_controller)
	session.match_controller = match_controller
	match_controller.setup(session)

	_wire(session)


static func _wire(session: RoomSessionNode) -> void:
	ConnectionManager.connected_to_host.connect(session._on_connected_to_host)
	ConnectionManager.peer_disconnected.connect(session.handlers.on_peer_disconnected)
	ConnectionManager.server_disconnected.connect(session.rejoin.on_server_disconnected)
	ConnectionManager.connection_failed.connect(session.rejoin.on_connection_failed)
	session.rpc_node.handshake_received.connect(session.handlers.on_handshake)
	session.rpc_node.leave_requested.connect(session.handlers.on_leave_requested)
	session.rpc_node.room_snapshot_received.connect(session.handlers.on_snapshot)
	session.rpc_node.room_closed_received.connect(_on_room_closed.bind(session))
	session.rpc_node.options_patch_received.connect(session._on_options_from_peer)
	session.rpc_node.profile_update_received.connect(session.handlers.apply_profile_update)
	session.rpc_node.kick_received.connect(_on_kick_received.bind(session))
	session.rpc_node.leave_acked.connect(func() -> void: session.teardown_local(true))
	session.rpc_node.member_left_received.connect(
		func(nickname: String) -> void: session.member_left.emit(nickname)
	)
	session.presence.member_grace_expired.connect(session.handlers.on_grace_expired)
	PlayerDataStore.data_changed.connect(
		func(_d: PlayerData) -> void: session.handlers.sync_local_profile()
	)


static func _on_room_closed(session: RoomSessionNode) -> void:
	var room_name := session.current_room.name if session.current_room else ""
	session.room_dissolved.emit(room_name)
	session.teardown_local(true)


static func _on_kick_received(session: RoomSessionNode) -> void:
	var room_name := session.current_room.name if session.current_room else ""
	session.kicked_from_room.emit(room_name)
	session.teardown_local(true)
