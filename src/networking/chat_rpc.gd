class_name ChatRpc
extends Node
## Thin RPC façade for ephemeral room chat (no history).

signal chat_submitted(peer_id: int, content: String)
signal chat_delivered(payload: Dictionary)


@rpc("any_peer", "reliable")
func submit_chat(content: String) -> void:
	if not multiplayer.is_server():
		return
	chat_submitted.emit(multiplayer.get_remote_sender_id(), content)


@rpc("authority", "reliable", "call_local")
func deliver_chat(payload: Dictionary) -> void:
	chat_delivered.emit(payload)


func send_chat(content: String) -> void:
	if multiplayer.is_server():
		chat_submitted.emit(multiplayer.get_unique_id(), content)
	else:
		submit_chat.rpc_id(1, content)


func broadcast_chat(payload: Dictionary) -> void:
	deliver_chat.rpc(payload)
