class_name RoomRejoin
extends Node
## Client-side reconnect to the last remembered host after disconnect / reload.

var _mgr: RoomManagerNode
var _attempts_left := NetConst.REJOIN_ATTEMPTS
var _active := false


func setup(manager: RoomManagerNode) -> void:
	_mgr = manager


func is_active() -> bool:
	return _active


func reset() -> void:
	_active = false
	_attempts_left = NetConst.REJOIN_ATTEMPTS


func try_startup() -> void:
	var data: PlayerData = PlayerDataStore.data
	if data == null or data.last_host_address.is_empty():
		return
	if _mgr.current_room != null or ConnectionManager.is_connected_peer():
		return
	_attempts_left = NetConst.REJOIN_ATTEMPTS
	BusyBlocker.begin("正在重新加入房间…")
	_continue_or_give_up()


func on_server_disconnected() -> void:
	if _mgr.is_leaving_voluntarily():
		_mgr.teardown_local(true)
		return
	if not BusyBlocker.is_busy():
		BusyBlocker.begin("正在重新加入房间…")
	_continue_or_give_up()


func on_connection_failed(reason: String) -> void:
	if _mgr.is_leaving_voluntarily():
		return
	if _active:
		# Defer so ConnectionManager.leave() in the fail path has fully finished
		# before we open a replacement socket.
		call_deferred("_continue_or_give_up")
		return
	_mgr.join_failed.emit(reason)


func _continue_or_give_up() -> void:
	var data: PlayerData = PlayerDataStore.data
	if data == null or data.last_host_address.is_empty() or _attempts_left <= 0:
		_give_up()
		return
	_active = true
	_attempts_left -= 1
	if BusyBlocker.is_busy():
		BusyBlocker.show_hint("正在重新加入房间…")
	var err := _mgr.join_room(data.last_host_address, data.last_host_port)
	if err != OK:
		call_deferred("_continue_or_give_up")


func _give_up() -> void:
	reset()
	_mgr.join_failed.emit("无法重新加入房间")
	_mgr.teardown_local(true)
