class_name NetEnv
extends Object
## Process-role helpers (dedicated vs client).


static func is_dedicated_server() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if OS.has_feature("dedicated_server"):
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--server" or arg.begins_with("--server="):
			return true
	return false
