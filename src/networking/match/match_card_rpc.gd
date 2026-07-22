class_name MatchCardRpc
extends Node
## Thin RPC façade for card snapshots, draws, and client play/pass requests.

signal card_snapshot_received(snapshot: Dictionary)
signal cards_drawn_received(card_ids: Array)
signal play_requested(peer_id: int, card_ids: Array)
signal pass_requested(peer_id: int)


@rpc("authority", "reliable", "call_remote")
func apply_card_snapshot(snapshot: Dictionary) -> void:
	card_snapshot_received.emit(snapshot)


@rpc("authority", "reliable", "call_remote")
func notify_cards_drawn(card_ids: Array) -> void:
	cards_drawn_received.emit(card_ids)


@rpc("any_peer", "reliable")
func request_play(card_ids: Array) -> void:
	if not multiplayer.is_server():
		return
	play_requested.emit(multiplayer.get_remote_sender_id(), card_ids)


@rpc("any_peer", "reliable")
func request_pass() -> void:
	if not multiplayer.is_server():
		return
	pass_requested.emit(multiplayer.get_remote_sender_id())


func send_snapshot_to(peer_id: int, snapshot: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if not _peer_connected(peer_id):
		return
	apply_card_snapshot.rpc_id(peer_id, snapshot)


func send_cards_drawn_to(peer_id: int, card_ids: Array) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if not _peer_connected(peer_id):
		return
	notify_cards_drawn.rpc_id(peer_id, card_ids)


func send_play(card_ids: Array) -> void:
	if not multiplayer.has_multiplayer_peer():
		print(
			"[MatchPlayTrace][transport.send_failed][%.3f] reason=no_multiplayer_peer ids=%s"
			% [Time.get_unix_time_from_system(), JSON.stringify(card_ids)]
		)
		return
	if multiplayer.is_server():
		print(
			"[MatchPlayTrace][transport.local_dispatch][%.3f] peer=%d ids=%s"
			% [
				Time.get_unix_time_from_system(),
				multiplayer.get_unique_id(),
				JSON.stringify(card_ids),
			]
		)
		play_requested.emit(multiplayer.get_unique_id(), card_ids)
	else:
		print(
			"[MatchPlayTrace][transport.rpc_sent][%.3f] peer=%d target=1 ids=%s"
			% [
				Time.get_unix_time_from_system(),
				multiplayer.get_unique_id(),
				JSON.stringify(card_ids),
			]
		)
		request_play.rpc_id(1, card_ids)


func send_pass() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		pass_requested.emit(multiplayer.get_unique_id())
	else:
		request_pass.rpc_id(1)


func _peer_connected(peer_id: int) -> bool:
	if peer_id <= 0:
		return false
	for id in multiplayer.get_peers():
		if int(id) == peer_id:
			return true
	return false
