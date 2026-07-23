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


## True when this build can spawn a sibling --server process via OS.create_process.
static func supports_local_dedicated_server() -> bool:
	if is_web() or is_mobile():
		return false
	# Dedicated-server processes should not spawn another dedicated server.
	if OS.has_feature("dedicated_server"):
		return false
	return true
