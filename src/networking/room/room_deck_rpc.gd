class_name RoomDeckRpc
extends Node
## RPC façade for room deck .tres transfer (separate from lobby RoomRpc).

signal deck_tres_requested(peer_id: int)
signal deck_tres_delivered(bytes: PackedByteArray, checksum: String)
signal deck_set_requested(peer_id: int, profile: Dictionary)


@rpc("any_peer", "reliable")
func request_deck_tres() -> void:
	if not multiplayer.is_server():
		return
	deck_tres_requested.emit(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func submit_set_deck(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	deck_set_requested.emit(multiplayer.get_remote_sender_id(), profile)


@rpc("authority", "reliable", "call_remote")
func deliver_deck_tres(bytes: PackedByteArray, checksum: String) -> void:
	deck_tres_delivered.emit(bytes, checksum)


func send_request_deck_tres() -> void:
	if multiplayer.is_server():
		deck_tres_requested.emit(1)
	else:
		request_deck_tres.rpc_id(1)


func send_set_deck(profile: Dictionary) -> void:
	if multiplayer.is_server():
		deck_set_requested.emit(multiplayer.get_unique_id(), profile)
	else:
		submit_set_deck.rpc_id(1, profile)


func send_deck_tres_to(peer_id: int, bytes: PackedByteArray, checksum: String) -> void:
	if peer_id <= 1:
		deck_tres_delivered.emit(bytes, checksum)
		return
	deliver_deck_tres.rpc_id(peer_id, bytes, checksum)
