class_name RoomDeckProfile
extends Resource
## Networked room deck selection meta (not the full DeckData payload).

@export var builtin: bool = true
## Builtin decks only: shared res:// path. Empty for user decks.
@export var path: String = ""
@export var id: String = ""
## MD5 of host .tres for user decks; empty for builtin.
@export var checksum: String = ""
@export var name: String = ""
@export var author: String = ""
@export var description: String = ""


func apply_from_deck(deck_path: String, deck: DeckData, is_builtin: bool, file_checksum: String = "") -> void:
	builtin = is_builtin
	path = deck_path if is_builtin else ""
	id = deck.id if deck else ""
	name = deck.name if deck else ""
	author = deck.author if deck else ""
	description = deck.description if deck else ""
	checksum = "" if is_builtin else file_checksum


func to_dict() -> Dictionary:
	return {
		"builtin": builtin,
		"path": path,
		"id": id,
		"checksum": checksum,
		"name": name,
		"author": author,
		"description": description,
	}


static func from_dict(data: Dictionary) -> RoomDeckProfile:
	var profile := RoomDeckProfile.new()
	profile.builtin = bool(data.get("builtin", true))
	profile.path = str(data.get("path", ""))
	profile.id = str(data.get("id", ""))
	profile.checksum = str(data.get("checksum", ""))
	profile.name = str(data.get("name", ""))
	profile.author = str(data.get("author", ""))
	profile.description = str(data.get("description", ""))
	return profile


static func from_deck_path(deck_path: String) -> RoomDeckProfile:
	var profile := RoomDeckProfile.new()
	if deck_path.is_empty():
		return profile
	var deck := DeckDataStore.load_deck(deck_path)
	if deck == null:
		return profile
	var is_builtin := ResourceFsUtils.is_builtin_path(deck_path)
	var file_checksum := "" if is_builtin else DeckDataStore.file_checksum(deck_path)
	profile.apply_from_deck(deck_path, deck, is_builtin, file_checksum)
	return profile


static func create_default_builtin() -> RoomDeckProfile:
	var builtin_path := DeckDataStore.first_builtin_path()
	if builtin_path.is_empty():
		return RoomDeckProfile.new()
	return from_deck_path(builtin_path)
