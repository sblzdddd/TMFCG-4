class_name MatchRpc
extends Node
## Thin RPC façade for match snapshots + logical-host commands (online).

signal match_snapshot_received(snapshot: Dictionary)
signal host_command_requested(peer_id: int, command: String, args: Dictionary)
signal start_countdown_received(seconds: int)


@rpc("authority", "reliable", "call_remote")
func apply_match_snapshot(snapshot: Dictionary) -> void:
	match_snapshot_received.emit(snapshot)


@rpc("authority", "reliable", "call_remote")
func notify_start_countdown(seconds: int) -> void:
	start_countdown_received.emit(seconds)


@rpc("any_peer", "reliable")
func request_host_command(command: String, args: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	host_command_requested.emit(multiplayer.get_remote_sender_id(), command, args)


func send_host_command(command: String, args: Dictionary = {}) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		host_command_requested.emit(multiplayer.get_unique_id(), command, args)
	else:
		request_host_command.rpc_id(1, command, args)


func broadcast(snapshot: Dictionary, peer_ids: Array = []) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server():
		return
	if peer_ids.is_empty():
		if NetEnv.is_dedicated_server():
			return
		apply_match_snapshot.rpc(snapshot)
		return
	for peer_id in peer_ids:
		var id := int(peer_id)
		if id <= 0:
			continue
		var found := false
		for live in multiplayer.get_peers():
			if int(live) == id:
				found = true
				break
		if found:
			apply_match_snapshot.rpc_id(id, snapshot)


func broadcast_start_countdown(seconds: int, peer_ids: Array = []) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server():
		return
	if peer_ids.is_empty():
		if NetEnv.is_dedicated_server():
			return
		notify_start_countdown.rpc(seconds)
		return
	for peer_id in peer_ids:
		var id := int(peer_id)
		if id <= 0:
			continue
		var found := false
		for live in multiplayer.get_peers():
			if int(live) == id:
				found = true
				break
		if found:
			notify_start_countdown.rpc_id(id, seconds)
