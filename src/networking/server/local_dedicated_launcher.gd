class_name LocalDedicatedLauncher
extends Node
## Spawns a headless dedicated-server sibling process (--server) and tracks its PID.

const PID_FILE := "user://tmfcg/local_server.pid"
const SERVER_SOURCE_FILES := [
	"res://src/networking/server/online_lobby_rpc.gd",
	"res://src/networking/server/server_room_registry.gd",
	"res://src/networking/server/server_room_runtime.gd",
	"res://src/networking/match/match_rpc.gd",
	"res://src/networking/match/match_controller.gd",
	"res://src/networking/match/match_start_flow.gd",
]

var _pid: int = -1
var _port: int = NetConst.GAME_PORT


func is_running() -> bool:
	var record := _read_process_record()
	var file_pid := int(record.get("pid", -1))
	if file_pid < 0 or not OS.is_process_running(file_pid):
		return false
	if str(record.get("fingerprint", "")) != server_fingerprint():
		return false
	_pid = file_pid
	return true


func ensure_running(port: int = NetConst.GAME_PORT) -> Error:
	_port = clampi(port, 1, 65535)
	if is_running():
		return OK
	var stale_record := _read_process_record()
	var stale_pid := int(stale_record.get("pid", -1))
	if stale_pid >= 0 and OS.is_process_running(stale_pid):
		print(
			"LocalDedicatedLauncher: replacing stale server pid=%d fingerprint=%s"
			% [stale_pid, str(stale_record.get("fingerprint", "legacy"))]
		)
		var kill_error := OS.kill(stale_pid)
		if kill_error != OK:
			push_error(
				"LocalDedicatedLauncher: failed to stop stale server pid=%d: %s"
				% [stale_pid, error_string(kill_error)]
			)
			return kill_error
		OS.delay_msec(250)
	_pid = -1
	var args := _build_args(_port)
	var pid := OS.create_process(OS.get_executable_path(), args, false)
	if pid < 0:
		push_error("LocalDedicatedLauncher: create_process failed")
		return ERR_CANT_CREATE
	_pid = pid
	print("LocalDedicatedLauncher: spawned dedicated server pid=%d port=%d" % [_pid, _port])
	return OK


## Replace an existing launcher-owned server when its source fingerprint is stale.
## Does not spawn anything when no PID record exists.
func refresh_if_managed(port: int = NetConst.GAME_PORT) -> Error:
	if not FileAccess.file_exists(PID_FILE):
		return OK
	var record := _read_process_record()
	var managed_pid := int(record.get("pid", -1))
	if managed_pid < 0 or not OS.is_process_running(managed_pid):
		return OK
	if str(record.get("fingerprint", "")) == server_fingerprint():
		_pid = managed_pid
		return OK
	return ensure_running(port)


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


func _read_process_record() -> Dictionary:
	if not FileAccess.file_exists(PID_FILE):
		return {}
	var f := FileAccess.open(PID_FILE, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text().strip_edges()
	f.close()
	# Backward compatibility: old launchers stored only the process ID.
	if text.is_valid_int():
		return {"pid": int(text), "fingerprint": ""}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func server_fingerprint() -> String:
	var hashes := PackedStringArray()
	for path in SERVER_SOURCE_FILES:
		hashes.append(FileAccess.get_md5(path))
	return "|".join(hashes).md5_text()
