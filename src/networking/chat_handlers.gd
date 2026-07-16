class_name ChatHandlers
extends Node
## Host validates chat; all peers append locally (no history).

const MAX_CHAT_LENGTH := 120

var _mgr: RoomManagerNode


func setup(manager: RoomManagerNode) -> void:
	_mgr = manager


func on_chat_submitted(peer_id: int, content: String) -> void:
	if not ConnectionManager.is_server():
		return
	var room: RoomData = _mgr.current_room
	if room == null:
		return
	var trimmed := content.strip_edges()
	if trimmed.is_empty() or trimmed.length() > MAX_CHAT_LENGTH:
		return
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return
	var entry: Dictionary = room.members[idx] as Dictionary
	var payload := {
		"uid": str(entry.get("uid", "")),
		"nickname": str(entry.get("nickname", "Player")),
		"avatar_id": str(entry.get("avatar_id", "")),
		"content": trimmed,
	}
	_mgr.chat_rpc.broadcast_chat(payload)


func on_chat_delivered(payload: Dictionary) -> void:
	if _mgr.current_room == null:
		return
	_mgr.chat_received.emit(payload)
