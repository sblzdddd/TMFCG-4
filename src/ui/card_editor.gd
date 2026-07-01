extends CanvasLayer

const CHARACTERS_DIR := "res://definitions/database/characters"
const CharacterUtilsLib = preload("res://src/dsl/character_utils.gd")

static var _thumbnail_cache: Dictionary = {}

@export var _character_picker: FileDialog
@export var _character_select_button: Button
@export var _character_name_label: Path2D
@export var _character_name_info: Label
@export var _character_description_label: Label
@export var _character_portrait: TextureRect

var selected_character: DialogicCharacter = null


func _ready() -> void:
	TranslationServer.set_locale("zh")
	_character_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_character_picker()
	_character_select_button.pressed.connect(_on_character_select_pressed)
	_character_picker.file_selected.connect(_on_character_file_selected)


func _setup_character_picker() -> void:
	_character_picker.access = FileDialog.ACCESS_RESOURCES
	_character_picker.use_native_dialog = false
	_character_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_character_picker.display_mode = FileDialog.DISPLAY_THUMBNAILS
	_character_picker.root_subfolder = CHARACTERS_DIR
	_character_picker.filters = PackedStringArray(["*.dch ; Character Definition"])
	_character_picker.title = "选择角色"
	FileDialog.set_get_thumbnail_callback(_get_dch_thumbnail)


static func _get_dch_thumbnail(path: String) -> Texture2D:
	if not path.to_lower().ends_with(".dch"):
		return null
	if _thumbnail_cache.has(path):
		return _thumbnail_cache[path]

	var character := load(path) as DialogicCharacter
	if character == null:
		return null

	var texture := character.generate_editor_preview()
	if texture != null:
		_thumbnail_cache[path] = texture
	return texture


func _on_character_select_pressed() -> void:
	_character_picker.popup_centered_ratio(0.6)


func _on_character_file_selected(path: String) -> void:
	if not path.ends_with(".dch"):
		return

	var character := load(path) as DialogicCharacter
	if character == null:
		push_warning("Failed to load character: %s" % path)
		return

	selected_character = character
	_apply_character(character)


func _apply_character(character: DialogicCharacter) -> void:
	var display_name := character.get_display_name_translated()
	if display_name.is_empty():
		display_name = character.get_character_name()

	_character_name_info.text = display_name
	var card_description := CharacterUtilsLib.get_card_description(character)
	_character_description_label.text = (
		card_description if not card_description.is_empty() else "【无角色描述】"
	)
	_character_name_label.text = CharacterUtilsLib.get_english_display_name(character)

	var texture := character.generate_editor_preview()
	if texture != null:
		_character_portrait.texture = texture
