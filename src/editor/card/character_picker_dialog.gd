extends FileDialog
class_name CharacterPickerDialog

signal character_selected(character: DialogicCharacter)

const CHARACTERS_DIR := "res://definitions/database/characters"

static var _thumbnail_cache: Dictionary = {}


func _ready() -> void:
	access = FileDialog.ACCESS_RESOURCES
	use_native_dialog = false
	file_mode = FileDialog.FILE_MODE_OPEN_FILE
	display_mode = FileDialog.DISPLAY_THUMBNAILS
	root_subfolder = CHARACTERS_DIR
	filters = PackedStringArray(["*.dch ; Character Definition"])
	title = "选择角色"
	file_selected.connect(_on_file_selected)
	FileDialog.set_get_thumbnail_callback(_get_dch_thumbnail)


func popup_picker() -> void:
	popup_centered_ratio(0.6)


static func _get_dch_thumbnail(path: String) -> Texture2D:
	if not path.to_lower().ends_with(".dch"):
		return null
	if _thumbnail_cache.has(path):
		return _thumbnail_cache[path]

	var character := load(path) as DialogicCharacter
	if character == null:
		return null

	var texture := CharacterUtils.get_preview_texture(character)
	if texture != null:
		_thumbnail_cache[path] = texture
	return texture


func _on_file_selected(path: String) -> void:
	if not path.to_lower().ends_with(".dch"):
		return

	var character := load(path) as DialogicCharacter
	if character == null:
		push_warning("Failed to load character: %s" % path)
		return

	character_selected.emit(character)
