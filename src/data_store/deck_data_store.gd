@tool
extends Node

## CRUD for DeckData (.tres) under preset + user deck dirs.

signal decks_changed
signal deck_changed(path: String)


func list_paths(include_builtin: bool = true) -> Array[String]:
	ResourceFsUtils.ensure_directories()
	var paths: Array[String] = []
	if include_builtin:
		paths.append_array(ResourceFsUtils.list_files(ResConst.PRESET_DECKS_DIR, "tres"))
	paths.append_array(ResourceFsUtils.list_files(ResConst.USER_DECKS_DIR, "tres"))
	return paths


func load_deck(path: String) -> DeckData:
	if path.is_empty():
		return null
	return load(path) as DeckData


func create_deck(
	deck_name: String,
	author: String = "",
	description: String = "",
	thumbnail_source: String = "",
	builtin: bool = false,
) -> Dictionary:
	## Returns { "deck": DeckData, "path": String } or empty on failure.
	if deck_name.strip_edges().is_empty():
		push_warning("Deck name is required.")
		return {}
	if builtin and not ResourceFsUtils.can_write_presets():
		push_warning("Builtin decks can only be created from the Godot editor.")
		return {}

	var filename := ResourceFsUtils.sanitize_filename(deck_name)
	var deck_path := ResourceFsUtils.make_unique_path(ResConst.decks_dir(builtin), deck_name, "tres")
	var deck := DeckData.new()
	deck.name = deck_name.strip_edges()
	deck.author = author.strip_edges()
	deck.description = description.strip_edges()
	deck.id = "deck-%d" % Time.get_unix_time_from_system()
	deck.date_created = Time.get_unix_time_from_system()
	deck.date_modified = deck.date_created
	deck.cards = CardUtils.create_default_deck_cards()

	if not thumbnail_source.is_empty():
		var image_path := thumbnail_source
		if (not builtin and image_path.begins_with("res://")) or image_path.begins_with("user://"):
			image_path = ResourceFsUtils.import_image_file(
				image_path, ResConst.textures_dir(ResConst.ImageKind.DECK_THUMBNAIL, builtin), filename
			)
		if not image_path.is_empty():
			deck.thumbnail = ResourceFsUtils.load_texture(image_path)
			deck.thumbnail_path = image_path

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
