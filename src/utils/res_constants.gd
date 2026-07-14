extends RefCounted
class_name ResConst

enum ImageKind {
	CHARACTER_PORTRAIT,
	DECK_THUMBNAIL,
}

enum ImagePickMode {
	UPLOAD,
	CHOOSE,
}

const USER_TEXTURES_DIR := "user://textures/"
const USER_CHARACTERS_DIR := "user://characters/"
const USER_DECKS_DIR := "user://decks/"
const USER_DIRS := [USER_TEXTURES_DIR, USER_CHARACTERS_DIR, USER_DECKS_DIR]

const PRESET_ROOT := "res://definitions/database/"
const PRESET_CHARACTERS_DIR := "res://definitions/database/characters/"
const PRESET_DECKS_DIR := "res://definitions/database/decks/"
const PRESET_CHARACTER_TEXTURES_DIR := "res://assets/textures/characters/"
const PRESET_DECK_TEXTURES_DIR := "res://assets/textures/decks/"
const AVATARS_DIR := "res://assets/textures/avatars/"
const PRESET_DIRS := [PRESET_CHARACTERS_DIR, PRESET_DECKS_DIR, PRESET_CHARACTER_TEXTURES_DIR, PRESET_DECK_TEXTURES_DIR]


static func characters_dir(builtin: bool) -> String:
	return PRESET_CHARACTERS_DIR if builtin else USER_CHARACTERS_DIR


static func decks_dir(builtin: bool) -> String:
	return PRESET_DECKS_DIR if builtin else USER_DECKS_DIR


static func textures_dir(kind: ResConst.ImageKind, builtin: bool) -> String:
	match kind:
		ImageKind.CHARACTER_PORTRAIT:
			return PRESET_CHARACTER_TEXTURES_DIR if builtin else USER_TEXTURES_DIR
		ImageKind.DECK_THUMBNAIL:
			return PRESET_DECK_TEXTURES_DIR if builtin else USER_TEXTURES_DIR
	return ""

static func upload_title(kind: ImageKind) -> String:
	match kind:
		ImageKind.CHARACTER_PORTRAIT:
			return "上传立绘"
		ImageKind.DECK_THUMBNAIL:
			return "上传缩略图"
	return "上传图片"


static func choose_title(kind: ImageKind) -> String:
	match kind:
		ImageKind.CHARACTER_PORTRAIT:
			return "选择立绘"
		ImageKind.DECK_THUMBNAIL:
			return "选择缩略图"
	return "选择图片"