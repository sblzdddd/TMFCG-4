extends Node

## Read-only access to DialogicCharacter (.dch) under the preset characters dir.
## Saving is allowed only as an editor feature (e.g. set default transform).

signal characters_changed
signal character_changed(path: String)


func list_paths() -> Array[String]:
	return ResourceFsUtils.list_files(ResConst.PRESET_CHARACTERS_DIR, "dch")


func load_character(path: String) -> DialogicCharacter:
	if path.is_empty():
		return null
	return load(path) as DialogicCharacter


func is_allowed_path(path: String) -> bool:
	return path.begins_with(ResConst.PRESET_CHARACTERS_DIR)


func save_character(character: DialogicCharacter, path: String = "") -> Error:
	if character == null:
		return ERR_INVALID_DATA
	var save_path := path if not path.is_empty() else character.resource_path
	if save_path.is_empty() or not is_allowed_path(save_path):
		return ERR_INVALID_DATA
	if not ResourceFsUtils.can_write_presets():
		push_warning("Cannot save character outside the editor.")
		return ERR_FILE_CANT_WRITE
	var err := ResourceFsUtils.save_resource(character, save_path)
	if err == OK:
		character_changed.emit(save_path)
		characters_changed.emit()
		DialogicResourceUtil.update_directory("dch")
	else:
		push_error("Failed to save character: %s" % error_string(err))
	return err
