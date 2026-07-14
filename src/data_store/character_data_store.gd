@tool
extends Node

## CRUD for DialogicCharacter (.dch) under preset + user character dirs.

signal characters_changed
signal character_changed(path: String)


func list_paths(include_builtin: bool = true) -> Array[String]:
	ResourceFsUtils.ensure_directories()
	var paths: Array[String] = []
	if include_builtin:
		paths.append_array(ResourceFsUtils.list_files(ResConst.PRESET_CHARACTERS_DIR, "dch"))
	paths.append_array(ResourceFsUtils.list_files(ResConst.USER_CHARACTERS_DIR, "dch"))
	return paths


func load_character(path: String) -> DialogicCharacter:
	if path.is_empty():
		return null
	return load(path) as DialogicCharacter


func is_allowed_path(path: String) -> bool:
	return (
		path.begins_with(ResConst.PRESET_CHARACTERS_DIR)
		or path.begins_with(ResConst.USER_CHARACTERS_DIR)
	)


func create_character(
	display_name: String,
	description: String = "",
	portrait_source: String = "",
	builtin: bool = false,
) -> Dictionary:
	## Returns { "character": DialogicCharacter, "path": String } or empty on failure.
	if display_name.strip_edges().is_empty():
		push_warning("Character name is required.")
		return {}
	if builtin and not ResourceFsUtils.can_write_presets():
		push_warning("Builtin characters can only be created from the Godot editor.")
		return {}

	var character := DialogicCharacter.new()
	character.display_name = display_name.strip_edges()
	character.description = description

	var character_path := ResourceFsUtils.make_unique_path(
		ResConst.characters_dir(builtin), display_name, "dch"
	)

	if not portrait_source.is_empty():
		var image_path := portrait_source
		if (not builtin and image_path.begins_with("res://")) or image_path.begins_with("user://"):
			image_path = ResourceFsUtils.import_image_file(
				image_path, ResConst.textures_dir(ResConst.ImageKind.CHARACTER_PORTRAIT, builtin), display_name
			)
		if not image_path.is_empty():
			character.add_portrait("default", image_path)
			character.default_portrait = "default"

	var err := save_character(character, character_path)
	if err != OK:
		return {}
	return {"character": character, "path": character_path}


func save_character(character: DialogicCharacter, path: String = "") -> Error:
	if character == null:
		return ERR_INVALID_DATA
	var save_path := path if not path.is_empty() else character.resource_path
	if save_path.is_empty():
		return ERR_INVALID_DATA
	var builtin := ResourceFsUtils.is_builtin_path(save_path)
	if builtin and not ResourceFsUtils.can_write_presets():
		push_warning("Cannot save built-in character outside the editor.")
		return ERR_FILE_CANT_WRITE
	var err := ResourceFsUtils.save_resource(character, path)
	if err == OK:
		character_changed.emit(save_path)
		characters_changed.emit()
		if builtin: DialogicResourceUtil.update_directory("dch")
	else:
		push_error("Failed to save character: %s" % error_string(err))
	return err


func delete_character(path: String) -> Error:
	if not ResourceFsUtils.can_delete(path):
		push_warning("Cannot delete built-in resources outside the editor.")
		return ERR_FILE_CANT_WRITE
	var err := ResourceFsUtils.delete_resource(path)
	if err == OK:
		characters_changed.emit()
	else:
		push_error("Failed to delete character: %s" % error_string(err))
	return err


func can_modify(path: String) -> bool:
	return ResourceFsUtils.can_delete(path)
