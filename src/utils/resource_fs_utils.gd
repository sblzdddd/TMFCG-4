@tool
extends RefCounted
class_name ResourceFsUtils

const USER_ROOT := "user://"
const USER_TEXTURES_DIR := USER_ROOT + "textures/"
const USER_CHARACTERS_DIR := USER_ROOT + "characters/"
const USER_DECKS_DIR := USER_ROOT + "decks/"

const PRESET_CHARACTERS_DIR := "res://definitions/database/characters/"
const PRESET_DECKS_DIR := "res://definitions/database/decks/"
const PRESET_CHARACTER_TEXTURES_DIR := "res://assets/textures/characters/"
const PRESET_DECK_TEXTURES_DIR := "res://assets/textures/decks/"

static var IMAGE_FILTERS := PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])


static func can_write_presets() -> bool:
	return OS.has_feature("editor")


static func ensure_user_dirs() -> void:
	ensure_directory(USER_TEXTURES_DIR)
	ensure_directory(USER_CHARACTERS_DIR)
	ensure_directory(USER_DECKS_DIR)


static func ensure_directory(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(global_path):
		DirAccess.make_dir_recursive_absolute(global_path)


static func ensure_preset_dirs() -> void:
	ensure_directory(PRESET_DECKS_DIR)
	ensure_directory(PRESET_DECK_TEXTURES_DIR)


static func get_characters_dir(builtin: bool) -> String:
	return PRESET_CHARACTERS_DIR if builtin else USER_CHARACTERS_DIR


static func get_decks_dir(builtin: bool) -> String:
	if builtin:
		ensure_preset_dirs()
	return PRESET_DECKS_DIR if builtin else USER_DECKS_DIR


static func get_textures_dir(builtin: bool) -> String:
	if builtin:
		ensure_preset_dirs()
	return PRESET_CHARACTER_TEXTURES_DIR if builtin else USER_TEXTURES_DIR


static func get_deck_textures_dir(builtin: bool) -> String:
	if builtin:
		ensure_preset_dirs()
	return PRESET_DECK_TEXTURES_DIR if builtin else USER_TEXTURES_DIR


static func sanitize_filename(name: String) -> String:
	var sanitized := name.strip_edges()
	sanitized = sanitized.replace("/", "_").replace("\\", "_").replace(":", "_")
	for ch in ['*', '?', '"', '<', '>', '|']:
		sanitized = sanitized.replace(ch, "_")
	if sanitized.is_empty():
		sanitized = "untitled"
	return sanitized


static func make_unique_path(dir: String, base_name: String, extension: String) -> String:
	ensure_directory(dir)
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
		_notify_resource_created(path)
	return err


static func save_dialogic_character(character: DialogicCharacter, path: String, builtin: bool) -> Error:
	var err := save_resource(character, path)
	if err == OK and builtin:
		DialogicResourceUtil.update_directory("dch")
	return err


static func pick_image_file(
	parent: Node,
	title: String,
	callback: Callable,
	access: FileDialog.Access = FileDialog.ACCESS_FILESYSTEM,
	root_subfolder: String = ""
) -> void:
	var dialog := FileDialog.new()
	dialog.title = title
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = access
	dialog.filters = IMAGE_FILTERS
	if not root_subfolder.is_empty():
		dialog.root_subfolder = root_subfolder
	dialog.file_selected.connect(func(path: String) -> void:
		callback.call(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	parent.add_child(dialog)
	dialog.popup_centered_ratio(0.6)


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


static func _notify_resource_created(_path: String) -> void:
	pass
