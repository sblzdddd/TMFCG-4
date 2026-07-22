class_name RoomUtils
extends RefCounted
## Shared room helpers for RoomSession.


static func scene_path(tree: SceneTree) -> String:
	if tree.current_scene:
		return tree.current_scene.scene_file_path
	return ""
