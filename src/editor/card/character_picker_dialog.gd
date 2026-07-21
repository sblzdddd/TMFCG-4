extends ThumbnailPickerDialog
class_name CharacterPickerDialog

signal character_selected(character: DialogicCharacter)

const FALLBACK_TEXTURE := preload("res://assets/textures/characters/Fallback.png")

static var _thumbnail_cache: Dictionary = {}


func _emit_selection(payload: Variant) -> void:
	super._emit_selection(payload)
	character_selected.emit(payload as DialogicCharacter)


func _collect_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for path in CharacterDataStore.list_paths():
		var character := CharacterDataStore.load_character(path)
		if character == null:
			continue
		var display_name := _get_display_name(character)
		entries.append({
			"display_name": display_name,
			"filter_text": display_name,
			"icon": _get_thumbnail(path, character),
			"payload": character,
		})
	return entries


static func _get_display_name(character: DialogicCharacter) -> String:
	var display_name := character.get_display_name_translated()
	if display_name.is_empty():
		display_name = character.get_character_name()
	if display_name.is_empty() and not character.resource_path.is_empty():
		display_name = character.resource_path.get_file().get_basename()
	return display_name


static func _get_thumbnail(path: String, character: DialogicCharacter) -> Texture2D:
	if _thumbnail_cache.has(path):
		return _thumbnail_cache[path]

	var texture := character.load_portrait_texture()
	if texture == null:
		texture = FALLBACK_TEXTURE
	_thumbnail_cache[path] = texture
	return texture


func _is_payload_allowed(payload: Variant) -> bool:
	var character := payload as DialogicCharacter
	if character == null:
		return false
	if character.resource_path.is_empty():
		return true
	if not CharacterDataStore.is_allowed_path(character.resource_path):
		push_warning("Character path outside allowed directories: %s" % character.resource_path)
		return false
	return true
