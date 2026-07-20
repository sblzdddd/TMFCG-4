extends RefCounted
class_name ResConst

const USER_TEXTURES_DIR := "user://tmfcg/textures/"
const USER_DECKS_DIR := "user://tmfcg/decks/"
const USER_DIRS := [USER_TEXTURES_DIR, USER_DECKS_DIR]

const PRESET_ROOT := "res://definitions/database/"
const PRESET_CHARACTERS_DIR := "res://definitions/database/characters/"
const PRESET_DECKS_DIR := "res://definitions/database/decks/"
const PRESET_CHARACTER_TEXTURES_DIR := "res://assets/textures/characters/"
const PRESET_SUIT_TEXTURES_DIR := "res://assets/textures/cards/suits/"
const AVATARS_DIR := "res://assets/textures/avatars/"
const PRESET_DIRS := [PRESET_CHARACTERS_DIR, PRESET_DECKS_DIR, PRESET_CHARACTER_TEXTURES_DIR]


static func decks_dir(builtin: bool) -> String:
	return PRESET_DECKS_DIR if builtin else USER_DECKS_DIR
