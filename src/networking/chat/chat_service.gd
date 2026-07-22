class_name ChatServiceNode
extends Node
## Autoload: ephemeral room chat (no history / no join restore).

signal chat_received(payload: Dictionary)

var chat_rpc: ChatRpc
var chat_handlers: ChatHandlers


func _ready() -> void:
	chat_rpc = ChatRpc.new()
	chat_rpc.name = "ChatRpc"
	add_child(chat_rpc)

	chat_handlers = ChatHandlers.new()
	chat_handlers.name = "ChatHandlers"
	add_child(chat_handlers)
	chat_handlers.setup(self)

	chat_rpc.chat_submitted.connect(chat_handlers.on_chat_submitted)
	chat_rpc.chat_delivered.connect(chat_handlers.on_chat_delivered)


func send_chat(content: String) -> void:
	if RoomSession.current_room == null or chat_rpc == null:
		return
	chat_rpc.send_chat(content)
