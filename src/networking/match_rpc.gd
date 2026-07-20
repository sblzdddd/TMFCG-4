class_name MatchRpc
extends Node
## Thin RPC façade for host → client match runtime snapshots.

signal match_snapshot_received(snapshot: Dictionary)


@rpc("authority", "reliable", "call_remote")
func apply_match_snapshot(snapshot: Dictionary) -> void:
	match_snapshot_received.emit(snapshot)


func broadcast(snapshot: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		apply_match_snapshot.rpc(snapshot)
