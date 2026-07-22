extends Node
## Always connect to a dedicated server: preferred host first, else spawn local --server.


signal mode_applied(online: bool)
signal central_connection_failed(reason: String)

const LOCAL_FALLBACK_ADDR := "127.0.0.1"
const LOCAL_JOIN_ATTEMPTS := 20
const LOCAL_JOIN_RETRY_SEC := 0.5

var _connecting_central := false
var _central_connected := false
var _using_local_fallback := false
var _fallback_in_progress := false
var _local_attempts_left := 0
var _launcher: LocalDedicatedLauncher


func _ready() -> void:
	if NetEnv.is_dedicated_server():
		return
	_launcher = LocalDedicatedLauncher.new()
	_launcher.name = "LocalDedicatedLauncher"
	add_child(_launcher)
	ConnectionManager.connected_to_host.connect(_on_connected)
	ConnectionManager.connection_failed.connect(_on_connection_failed)
	ConnectionManager.server_disconnected.connect(_on_server_disconnected)
	call_deferred("apply_preferred_mode")


func is_central_connected() -> bool:
	return _central_connected


func is_connecting_central() -> bool:
	return _connecting_central or _fallback_in_progress


func is_using_local_fallback() -> bool:
	return _using_local_fallback


## Awaitable: ensure a central link (remote or local fallback). Returns true if connected.
func ensure_central_async() -> bool:
	if NetEnv.is_dedicated_server():
		return false
	if is_central_connected():
		return true
	# Defer apply so the await below is armed before mode_applied can fire.
	if not is_connecting_central():
		call_deferred("apply_preferred_mode")
	var online: bool = await mode_applied
	return online and is_central_connected()


func apply_preferred_mode() -> void:
	if NetEnv.is_dedicated_server():
		return
	# Don't tear down a healthy mid-room link.
	if (
		RoomSession.current_room != null
		and _central_connected
		and ConnectionManager.is_connected_peer()
		and not ConnectionManager.is_server()
	):
		return
	_using_local_fallback = false
	_fallback_in_progress = false
	_local_attempts_left = 0
	_central_connected = false
	_connecting_central = false
	if ConnectionManager.is_connected_peer() and not ConnectionManager.is_server():
		ConnectionManager.leave()
	_try_connect_preferred()


func _try_connect_preferred() -> void:
	var data: SettingsData = SettingsDataStore.data
	if data == null:
		_fail_completely("settings missing")
		return
	if _connecting_central:
		return
	var address := data.server_address.strip_edges()
	if address.to_lower() in ["127.0.0.1", "localhost", "::1"]:
		var refresh_error := _launcher.refresh_if_managed(data.server_port)
		if refresh_error != OK:
			_on_preferred_failed(
				"failed to refresh local server: %s" % error_string(refresh_error)
			)
			return
	_connecting_central = true
	_central_connected = false
	var err := ConnectionManager.join(address, data.server_port)
	if err != OK:
		_on_preferred_failed("join failed: %s" % error_string(err))


func _on_preferred_failed(reason: String) -> void:
	_connecting_central = false
	_start_local_fallback(reason)


func _start_local_fallback(remote_reason: String) -> void:
	_fallback_in_progress = true
	_using_local_fallback = true
	var err := _launcher.ensure_running(NetConst.GAME_PORT)
	if err != OK:
		_fail_completely(
			"无法启动本地服务器 (%s); 远程: %s" % [error_string(err), remote_reason]
		)
		return
	Toast.push("无法连接服务器，已启动本地服务器")
	_local_attempts_left = LOCAL_JOIN_ATTEMPTS
	_try_join_local()


func _try_join_local() -> void:
	if not _fallback_in_progress:
		return
	if _local_attempts_left <= 0:
		_fail_completely("无法连接本地服务器")
		return
	_local_attempts_left -= 1
	_connecting_central = true
	var err := ConnectionManager.join(LOCAL_FALLBACK_ADDR, NetConst.GAME_PORT)
	if err != OK:
		_connecting_central = false
		_schedule_local_retry()


func _schedule_local_retry() -> void:
	var tree := get_tree()
	if tree == null:
		_fail_completely("无法连接本地服务器")
		return
	tree.create_timer(LOCAL_JOIN_RETRY_SEC).timeout.connect(
		_try_join_local, CONNECT_ONE_SHOT
	)


func _fail_completely(reason: String) -> void:
	_connecting_central = false
	_central_connected = false
	_fallback_in_progress = false
	_using_local_fallback = false
	_local_attempts_left = 0
	central_connection_failed.emit(reason)
	Toast.push("无法连接服务器")
	mode_applied.emit(false)


func _on_connected() -> void:
	if ConnectionManager.is_server():
		return
	if not _connecting_central and not _fallback_in_progress:
		return
	_connecting_central = false
	_central_connected = true
	_fallback_in_progress = false
	_local_attempts_left = 0
	mode_applied.emit(true)


func _on_connection_failed(reason: String) -> void:
	if ConnectionManager.is_server():
		return
	if _fallback_in_progress:
		_connecting_central = false
		_schedule_local_retry()
		return
	if _connecting_central:
		_on_preferred_failed(reason)


func _on_server_disconnected() -> void:
	_central_connected = false
	_connecting_central = false
	if RoomSession.is_leaving_voluntarily():
		return
	# Restore central (remote or local spawn); RoomRejoin waits on mode_applied when in a room.
	apply_preferred_mode()
