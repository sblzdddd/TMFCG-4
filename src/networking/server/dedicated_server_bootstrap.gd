extends Node
## Headless / --server entry: listen and host ServerRoomRegistry.

const PID_FILE := "user://tmfcg/local_server.pid"

var registry: ServerRoomRegistry
var _dedicated := false


func _ready() -> void:
	_dedicated = NetEnv.is_dedicated_server()
	if not _dedicated:
		return
	var port := _resolve_port()
	var err := ConnectionManager.host(port)
	if err != OK:
		push_error("Dedicated server failed to listen on %d: %s" % [port, error_string(err)])
		return
	_write_pid_file(OS.get_process_id())
	registry = ServerRoomRegistry.new()
	registry.name = "ServerRoomRegistry"
	add_child(registry)
	registry.setup()
	print("Dedicated server listening on port %d" % port)
	call_deferred("_enter_server_scene")


func is_running() -> bool:
	return _dedicated and registry != null


func _enter_server_scene() -> void:
	if ResourceLoader.exists("res://definitions/levels/dedicated_server.tscn"):
		LevelLoader.load_level("res://definitions/levels/dedicated_server.tscn")


func _resolve_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			var value := arg.get_slice("=", 1)
			if value.is_valid_int():
				return clampi(int(value), 1, 65535)
	return NetConst.GAME_PORT


func _write_pid_file(pid: int) -> void:
	ResourceFsUtils.ensure_directories()
	var f := FileAccess.open(PID_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(str(pid))
	f.close()
