extends RefCounted
class_name AvatarUtils

const DEFAULT_AVATAR_ID := "00000"


static func path_for_id(avatar_id: String) -> String:
	if avatar_id.is_empty():
		return ""
	return ResConst.AVATARS_DIR.path_join("%s.png" % avatar_id)


static func load_texture(avatar_id: String) -> Texture2D:
	var path := path_for_id(avatar_id)
	if path.is_empty(): return null
	return ResourceFsUtils.load_texture(path)


static func list_avatar_ids() -> Array[String]:
	var ids: Array[String] = []
	for path in ResourceFsUtils.list_files(ResConst.AVATARS_DIR, "png"):
		ids.append(path.get_file().get_basename())
	return ids


static func resolve_or_default(avatar_id: String) -> String:
	if not avatar_id.is_empty() and ResourceLoader.exists(path_for_id(avatar_id)):
		return avatar_id
	return DEFAULT_AVATAR_ID
