class_name RoomRejoin
extends Node
## Client-side reconnect to the last room code after disconnect / reload.


var _session: RoomSessionNode
var _attempts_left := NetConst.REJOIN_ATTEMPTS
var _active := false
var _response_timer: SceneTreeTimer
var _waiting_for_central := false


func setup(session: RoomSessionNode) -> void:
	_session = session
	_session.room_changed.connect(_on_room_changed)
	_session.join_failed.connect(_on_join_failed)
	NetworkModeService.mode_applied.connect(_on_mode_applied)


func is_active() -> bool:
	return _active


func reset() -> void:
	_active = false
	_waiting_for_central = false
	_attempts_left = NetConst.REJOIN_ATTEMPTS
	_cancel_response_timeout()


func try_startup() -> void:
	if NetEnv.is_dedicated_server():
		return
	var data: PlayerData = PlayerDataStore.data
	if data == null or data.last_room_code.is_empty():
		return
	if _session.current_room != null:
		return
	_attempts_left = NetConst.REJOIN_ATTEMPTS
	_active = true
	BusyBlocker.begin("正在重新加入房间…")
	if NetworkModeService.is_central_connected():
		_continue_or_give_up()
	else:
		_waiting_for_central = true
		BusyBlocker.show_hint("正在连接服务器…")
		_arm_response_timeout()


func on_server_disconnected() -> void:
	if _session.is_leaving_voluntarily():
		_session.teardown_room_keep_connection(true)
		return
	if _session.current_room == null:
		return
	if not BusyBlocker.is_busy():
		BusyBlocker.begin("正在重新加入房间…")
	_active = true
	_attempts_left = NetConst.REJOIN_ATTEMPTS
	_waiting_for_central = true
	BusyBlocker.show_hint("正在连接服务器…")
	_arm_response_timeout()
	# NetworkModeService will reconnect (remote or local fallback) and emit mode_applied.


func on_connection_failed(_reason: String) -> void:
	if _session.is_leaving_voluntarily():
		return
	if _active and not _waiting_for_central:
		call_deferred("_continue_or_give_up")
		return
	if not _active:
		_session.join_failed.emit(_reason)


func _on_mode_applied(online: bool) -> void:
	if not _active or not _waiting_for_central:
		return
	_waiting_for_central = false
	_cancel_response_timeout()
	if online and NetworkModeService.is_central_connected():
		_continue_or_give_up()
		return
	_give_up("无法连接服务器，已取消重新加入")


func _continue_or_give_up() -> void:
	var data: PlayerData = PlayerDataStore.data
	if data == null or data.last_room_code.is_empty() or _attempts_left <= 0:
		_give_up()
		return
	_active = true
	_attempts_left -= 1
	if BusyBlocker.is_busy():
		BusyBlocker.show_hint("正在重新加入房间…")
	_arm_response_timeout()
	if not NetworkModeService.is_central_connected():
		_waiting_for_central = true
		return
	var err := _session.join_room_code(data.last_room_code)
	if err != OK:
		_cancel_response_timeout()
		call_deferred("_continue_or_give_up")


func _arm_response_timeout() -> void:
	_cancel_response_timeout()
	var tree := get_tree()
	if tree == null:
		call_deferred("_give_up")
		return
	_response_timer = tree.create_timer(NetConst.JOIN_TIMEOUT_SEC)
	_response_timer.timeout.connect(_on_response_timeout, CONNECT_ONE_SHOT)


func _cancel_response_timeout() -> void:
	if _response_timer != null and _response_timer.timeout.is_connected(_on_response_timeout):
		_response_timer.timeout.disconnect(_on_response_timeout)
	_response_timer = null


func _on_response_timeout() -> void:
	_response_timer = null
	if not _active:
		return
	if _session.current_room != null:
		reset()
		return
	if _waiting_for_central:
		_give_up("连接服务器超时，已取消重新加入")
		return
	call_deferred("_continue_or_give_up")


func _on_room_changed(room: RoomData) -> void:
	if room != null and _active:
		reset()


func _on_join_failed(_reason: String) -> void:
	if not _active:
		return
	_give_up(_reason)


func _give_up(reason: String = "无法重新加入房间") -> void:
	reset()
	PlayerDataStore.clear_last_room()
	_session.join_failed.emit(reason)
	if _session.current_room != null:
		_session.teardown_room_keep_connection(false)
	elif BusyBlocker.is_busy():
		BusyBlocker.end(reason)
