extends Node

## CRUD for DeckData (.tres) under preset + user deck dirs.

signal decks_changed
signal deck_changed(path: String)

const TRANSFER_TEMP_PATH := "user://tmfcg/decks/_transfer_tmp.tres"


func list_paths(include_builtin: bool = true) -> Array[String]:
	ResourceFsUtils.ensure_directories()
	var paths: Array[String] = []
	if include_builtin:
		paths.append_array(ResourceFsUtils.list_files(ResConst.PRESET_DECKS_DIR, "tres"))
	for path in ResourceFsUtils.list_files(ResConst.USER_DECKS_DIR, "tres"):
		if path == TRANSFER_TEMP_PATH:
			continue
		paths.append(path)
	return paths


func first_builtin_path() -> String:
	var paths := ResourceFsUtils.list_files(ResConst.PRESET_DECKS_DIR, "tres")
	return paths[0] if not paths.is_empty() else ""


func file_checksum(path: String) -> String:
	if path.is_empty():
		return ""
	var global_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	if not FileAccess.file_exists(global_path) and not FileAccess.file_exists(path):
		return ""
	var md5 := FileAccess.get_md5(path)
	if md5.is_empty() and global_path != path:
		md5 = FileAccess.get_md5(global_path)
	return md5


func find_by_checksum(md5: String) -> String:
	if md5.is_empty():
		return ""
	for path in list_paths(false):
		if path == TRANSFER_TEMP_PATH:
			continue
		if file_checksum(path) == md5:
			return path
	return ""


func read_tres_bytes(path: String) -> PackedByteArray:
	if path.is_empty():
		return PackedByteArray()
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func import_tres_bytes(bytes: PackedByteArray, dest_path: String) -> Error:
	if bytes.is_empty() or dest_path.is_empty():
		return ERR_INVALID_DATA
	ResourceFsUtils.ensure_directories()
	var file := FileAccess.open(dest_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	var deck := load_deck(dest_path)
	if deck == null:
		return ERR_PARSE_ERROR
	return OK


func load_deck(path: String) -> DeckData:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return load(path) as DeckData


func create_deck(
	deck_name: String,
	author: String = "",
	description: String = "",
	builtin: bool = false,
) -> Dictionary:
	## Returns { "deck": DeckData, "path": String } or empty on failure.
	if deck_name.strip_edges().is_empty():
		push_warning("Deck name is required.")
		return {}
	if builtin and not ResourceFsUtils.can_write_presets():
		push_warning("Builtin decks can only be created from the Godot editor.")
		return {}

	var deck_path := ResourceFsUtils.make_unique_path(ResConst.decks_dir(builtin), deck_name, "tres")
	var deck := DeckData.new()
	deck.name = deck_name.strip_edges()
	deck.author = author.strip_edges()
	deck.description = description.strip_edges()
	deck.id = "deck-%d" % Time.get_unix_time_from_system()
	deck.date_created = Time.get_unix_time_from_system()
	deck.date_modified = deck.date_created
	deck.cards = CardUtils.create_default_deck_cards()

	var err := save_deck(deck, deck_path, true)
	if err != OK:
		return {}
	return {"deck": deck, "path": deck_path}


func save_deck(deck: DeckData, path: String, structural: bool = false) -> Error:
	if deck == null or path.is_empty():
		return ERR_INVALID_DATA
	deck.date_modified = Time.get_unix_time_from_system()
	var err := ResourceFsUtils.save_resource(deck, path)
	if err == OK:
		deck_changed.emit(path)
		if structural:
			decks_changed.emit()
	else:
		push_error("Failed to save deck: %s" % error_string(err))
	return err


func delete_deck(path: String) -> Error:
	if not ResourceFsUtils.can_delete(path):
		push_warning("Cannot delete built-in resources outside the editor.")
		return ERR_FILE_CANT_WRITE
	var err := ResourceFsUtils.delete_resource(path)
	if err == OK:
		decks_changed.emit()
	else:
		push_error("Failed to delete deck: %s" % error_string(err))
	return err


func add_card(deck_path: String, suit: CardEnums.Suit, rank: CardEnums.Rank) -> int:
	## Returns new card index, or -1 on failure.
	var deck := load_deck(deck_path)
	if deck == null:
		return -1
	var card := CardUtils.create_card(suit, rank)
	card.cardId = "card-%d-%d-%d" % [deck.cards.size(), int(suit), int(rank)]
	deck.cards.append(card)
	if save_deck(deck, deck_path) != OK:
		return -1
	return deck.cards.size() - 1


func remove_card(deck_path: String, card_index: int) -> Error:
	var deck := load_deck(deck_path)
	if deck == null or card_index < 0 or card_index >= deck.cards.size():
		return ERR_INVALID_PARAMETER
	if not ResourceFsUtils.can_delete(deck_path):
		push_warning("Cannot delete cards from this deck.")
		return ERR_FILE_CANT_WRITE
	deck.cards.remove_at(card_index)
	return save_deck(deck, deck_path)


func can_modify(path: String) -> bool:
	return ResourceFsUtils.can_delete(path)
