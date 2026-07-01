extends FileDialog
class_name CharacterPickerDialog

signal character_selected(character: DialogicCharacter)

enum CharacterLibrary {
	PRESET,
	USER,
}

const PRESET_CHARACTERS_DIR := "res://definitions/database/characters"
const USER_CHARACTERS_DIR := "user://tmfcg/characters/"

static var _thumbnail_cache: Dictionary = {}


func _ready() -> void:
	ensure_user_characters_dir()
	use_native_dialog = false
	file_mode = FileDialog.FILE_MODE_OPEN_FILE
	display_mode = FileDialog.DISPLAY_THUMBNAILS
	filters = PackedStringArray(["*.dch ; Character Definition"])
	file_selected.connect(_on_file_selected)
	FileDialog.set_get_thumbnail_callback(_get_dch_thumbnail)
	_configure_library(CharacterLibrary.PRESET)
	about_to_popup.connect(_hide_path_bar)
	_hide_path_bar()


func _hide_path_bar() -> void:
	var filename_edit := get_line_edit()
	var vbox := get_vbox()
	if filename_edit == null or vbox == null:
		return

	for child in vbox.get_children(true):
		_hide_path_bar_recursive(child, filename_edit)


func _hide_path_bar_recursive(node: Node, filename_edit: LineEdit) -> void:
	if node is LineEdit and node != filename_edit:
		var row := node.get_parent()
		if row:
			row.visible = false
		return

	for child in node.get_children(true):
		_hide_path_bar_recursive(child, filename_edit)


static func ensure_user_characters_dir() -> void:
	if not DirAccess.dir_exists_absolute(USER_CHARACTERS_DIR):
		DirAccess.make_dir_recursive_absolute(USER_CHARACTERS_DIR)


static func is_allowed_character_path(path: String) -> bool:
	return path.begins_with(PRESET_CHARACTERS_DIR) or path.begins_with(USER_CHARACTERS_DIR)


func popup_preset_picker() -> void:
	_open_library(CharacterLibrary.PRESET)


func popup_user_picker() -> void:
	_open_library(CharacterLibrary.USER)


func _open_library(source: CharacterLibrary) -> void:
	_configure_library(source)
	popup_centered_ratio(0.6)


func _configure_library(source: CharacterLibrary) -> void:
	match source:
		CharacterLibrary.PRESET:
			access = FileDialog.ACCESS_RESOURCES
			root_subfolder = PRESET_CHARACTERS_DIR
			title = "选择预设角色"
		CharacterLibrary.USER:
			access = FileDialog.ACCESS_USERDATA
			root_subfolder = USER_CHARACTERS_DIR
			title = "选择自定义角色"


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
	if not is_allowed_character_path(path):
		push_warning("Character path outside allowed directories: %s" % path)
		return

	var character := load(path) as DialogicCharacter
	if character == null:
		push_warning("Failed to load character: %s" % path)
		return

	character_selected.emit(character)
