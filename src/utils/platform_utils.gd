extends RefCounted
class_name PlatformUtils


static func is_mobile() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


static func is_web() -> bool:
	return OS.has_feature("web")


static func is_macos() -> bool:
	return OS.has_feature("macos")


## True when this build can spawn a sibling --server process via OS.create_process.
static func supports_local_dedicated_server() -> bool:
	if is_web() or is_mobile():
		return false
	# Dedicated-server processes should not spawn another dedicated server.
	if OS.has_feature("dedicated_server"):
		return false
	return true


## True if a process with this PID is alive.
## Unlike OS.is_process_running, this works for arbitrary PIDs (e.g. a local
## dedicated server from a previous launch). On Unix, Godot's check uses waitpid
## and errors with ECHILD for non-child PIDs.
static func is_pid_alive(pid: int) -> bool:
	if pid <= 0:
		return false
	# Windows OpenProcess accepts any accessible PID.
	if OS.get_name() == "Windows":
		return OS.is_process_running(pid)
	# Signal 0: existence/permission check, no signal delivered.
	var exit_code := OS.execute("kill", PackedStringArray(["-0", str(pid)]), [], true)
	return exit_code == 0
