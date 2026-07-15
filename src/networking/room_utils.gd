class_name RoomUtils
extends RefCounted
## Shared room teardown / advertise helpers for RoomManager.

static func local_lan_address() -> String:
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.begins_with("127.") or s.contains(":"):
			continue
		return s
	return "127.0.0.1"


static func scene_path(tree: SceneTree) -> String:
	if tree.current_scene:
		return tree.current_scene.scene_file_path
	return ""
