@tool
extends RefCounted
class_name ResourceFsUtils

enum ImagePickMode {
	UPLOAD,
	CHOOSE,
}

class ImagePickerConfig:
	var title: String
	var access: FileDialog.Access
	var root_subfolder: String = ""

static var IMAGE_FILTERS := PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])


static func can_write_presets() -> bool:
	return OS.has_feature("editor")


static func ensure_directories() -> void:
	var dirs := ResConst.USER_DIRS
	if Engine.is_editor_hint():
		dirs.append_array(ResConst.PRESET_DIRS)
	for dir in dirs:
		var global_path := ProjectSettings.globalize_path(dir)
		if not DirAccess.dir_exists_absolute(global_path):
			DirAccess.make_dir_recursive_absolute(global_path)


static func sanitize_filename(name: String) -> String:
	var sanitized := name.strip_edges()
	sanitized = sanitized.replace("/", "_").replace("\\", "_").replace(":", "_")
	for ch in ['*', '?', '"', '<', '>', '|']:
		sanitized = sanitized.replace(ch, "_")
	if sanitized.is_empty():
		sanitized = "untitled"
	return sanitized


static func make_unique_path(dir: String, base_name: String, extension: String) -> String:
	ensure_directories()
	var ext := extension.trim_prefix(".")
	var candidate := dir.path_join("%s.%s" % [base_name, ext])
	if not FileAccess.file_exists(candidate):
		return candidate

	var index := 1
	while index < 10000:
		candidate = dir.path_join("%s_%d.%s" % [base_name, index, ext])
		if not FileAccess.file_exists(candidate):
			return candidate
		index += 1
	return candidate


static func import_image_file(source_path: String, dest_dir: String, dest_basename: String) -> String:
	if source_path.is_empty():
		return ""

	var source_global := _to_global_path(source_path)
	if not FileAccess.file_exists(source_global):
		push_error("Image source does not exist: %s" % source_path)
		return ""

	var ext := source_path.get_extension().to_lower()
	if ext.is_empty():
		ext = "png"

	var dest_path := make_unique_path(dest_dir, sanitize_filename(dest_basename), ext)
	var err := DirAccess.copy_absolute(source_global, ProjectSettings.globalize_path(dest_path))
	if err != OK:
		push_error("Failed to copy image to %s: %s" % [dest_path, error_string(err)])
		return ""

	return dest_path


static func save_resource(resource: Resource, path: String) -> Error:
	resource.resource_path = path
	var err := ResourceSaver.save(resource, path)
	if err == OK:
		_on_resource_created(path)
	return err


static func save_dialogic_character(character: DialogicCharacter, path: String, builtin: bool) -> Error:
	var err := save_resource(character, path)
	if err == OK and builtin:
		DialogicResourceUtil.update_directory("dch")
	return err


static func new_deck_path(deck_name: String, builtin: bool) -> String:
	return make_unique_path(ResConst.decks_dir(builtin), sanitize_filename(deck_name), "tres")


static func new_character_path(display_name: String, builtin: bool) -> String:
	return make_unique_path(ResConst.characters_dir(builtin), sanitize_filename(display_name), "dch")


static func resolve_deck_thumbnail(source_path: String, dest_basename: String, builtin: bool) -> String:
	if source_path.is_empty():
		return ""
	if source_path.begins_with("res://") or source_path.begins_with("user://"):
		if not builtin and source_path.begins_with("res://"):
			return import_image_file(source_path, ResConst.textures_dir(ResConst.ImageKind.DECK_THUMBNAIL, false), dest_basename)
		return source_path
	return import_image_file(source_path, ResConst.textures_dir(ResConst.ImageKind.DECK_THUMBNAIL, builtin), dest_basename)


static func resolve_character_portrait(source_path: String, dest_basename: String, builtin: bool) -> String:
	if source_path.is_empty():
		return ""
	if source_path.begins_with("res://") or source_path.begins_with("user://"):
		if not builtin and source_path.begins_with("res://"):
			return import_image_file(source_path, ResConst.textures_dir(ResConst.ImageKind.CHARACTER_PORTRAIT, false), dest_basename)
		return source_path
	return import_image_file(source_path, ResConst.textures_dir(ResConst.ImageKind.CHARACTER_PORTRAIT, builtin), dest_basename)


static func list_files(dir: String, extension: String) -> Array[String]:
	var results: Array[String] = []
	var global_dir := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(global_dir):
		return results

	var ext := extension.trim_prefix(".").to_lower()
	var dir_access := DirAccess.open(dir)
	if dir_access == null:
		return results

	dir_access.list_dir_begin()
	var entry_name := dir_access.get_next()
	while not entry_name.is_empty():
		if not dir_access.current_is_dir() and entry_name.get_extension().to_lower() == ext:
			results.append(dir.path_join(entry_name))
		entry_name = dir_access.get_next()
	dir_access.list_dir_end()

	results.sort()
	return results


static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(_to_global_path(path)):
		return null
	return ResourceLoader.load(path) as Texture2D


static func _to_global_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path




static func can_delete(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("user://"):
		return true
	if path.begins_with("res://"):
		return can_write_presets()
	return false


static func delete_resource(path: String) -> Error:
	if not can_delete(path):
		return ERR_FILE_CANT_WRITE
	var global_path := _to_global_path(path)
	if not FileAccess.file_exists(global_path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(global_path)


static func is_builtin_path(path: String) -> bool:
	return path.begins_with(ResConst.PRESET_ROOT)


static func _on_resource_created(_path: String) -> void:
	pass
