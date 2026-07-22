class_name LocalDedicatedLauncher
extends Node
## Spawns a headless dedicated-server sibling process (--server) and tracks its PID.

const PID_FILE := "user://tmfcg/local_server.pid"

var _pid: int = -1
var _port: int = NetConst.GAME_PORT


func is_running() -> bool:
	if _pid >= 0 and OS.is_process_running(_pid):
		return true
	var file_pid := _read_pid_file()
	if file_pid >= 0 and OS.is_process_running(file_pid):
		_pid = file_pid
		return true
	return false


func ensure_running(port: int = NetConst.GAME_PORT) -> Error:
	_port = clampi(port, 1, 65535)
	if is_running():
		return OK
	_pid = -1
	var args := _build_args(_port)
	var pid := OS.create_process(OS.get_executable_path(), args, false)
	if pid < 0:
		push_error("LocalDedicatedLauncher: create_process failed")
		return ERR_CANT_CREATE
	_pid = pid
	_write_pid_file(_pid)
	print("LocalDedicatedLauncher: spawned dedicated server pid=%d port=%d" % [_pid, _port])
	return OK


func get_port() -> int:
	return _port


func _build_args(port: int) -> PackedStringArray:
	var args: PackedStringArray = []
	if OS.has_feature("editor"):
		args.append("--path")
		args.append(ProjectSettings.globalize_path("res://"))
	args.append("--headless")
	args.append("--")
	args.append("--server")
	args.append("--port=%d" % port)
	return args


func _write_pid_file(pid: int) -> void:
	ResourceFsUtils.ensure_directories()
	var f := FileAccess.open(PID_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(str(pid))
	f.close()


func _read_pid_file() -> int:
	if not FileAccess.file_exists(PID_FILE):
		return -1
	var f := FileAccess.open(PID_FILE, FileAccess.READ)
	if f == null:
		return -1
	var text := f.get_as_text().strip_edges()
	f.close()
	if text.is_valid_int():
		return int(text)
	return -1
