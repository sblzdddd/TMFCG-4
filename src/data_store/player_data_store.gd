extends Node

## Loads / creates local player data under user:// and exposes it for UI + networking.

const SAVE_PATH := "user://player_data.tres"

signal data_changed(data: PlayerData)

var data: PlayerData


func _ready() -> void:
	load_or_create()


func load_or_create() -> PlayerData:
	if FileAccess.file_exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerData
		if loaded != null:
			data = loaded
			_normalize_loaded_data()
			return data
	data = _create_default()
	save()
	return data


func save() -> Error:
	if data == null:
		return ERR_INVALID_DATA
	return ResourceFsUtils.save_resource(data, SAVE_PATH)


func get_profile() -> PlayerProfile:
	return data.to_profile() if data != null else PlayerProfile.new("Player")


func set_display_name(new_name: String) -> void:
	if data == null:
		return
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty() or data.name == trimmed:
		return
	data.name = trimmed
	save()
	data_changed.emit(data)


func set_avatar_id(avatar_id: String) -> void:
	if data == null:
		return
	var resolved := AvatarUtils.resolve_or_default(avatar_id)
	if data.avatar_id == resolved and data.avatar != null:
		return
	data.avatar_id = resolved
	data.avatar = AvatarUtils.load_texture(resolved)
	save()
	data_changed.emit(data)


func _normalize_loaded_data() -> void:
	data.avatar_id = AvatarUtils.resolve_or_default(str(data.avatar_id))
	if data.avatar == null:
		data.avatar = AvatarUtils.load_texture(data.avatar_id)
	if data.uid.is_empty():
		data.uid = PlayerId.new().value
	if data.name.strip_edges().is_empty():
		data.name = random_display_name()
	save()


func _create_default() -> PlayerData:
	var created := PlayerData.new()
	created.uid = PlayerId.new().value
	created.name = random_display_name()
	created.avatar_id = AvatarUtils.DEFAULT_AVATAR_ID
	created.avatar = AvatarUtils.load_texture(created.avatar_id)
	created.date_joined = Time.get_unix_time_from_system()
	return created


func random_display_name() -> String:
	var prefixes: Array[String] = []
	var suffixes: Array[String] = []

	for path in CharacterDataStore.list_paths(true):
		var character := CharacterDataStore.load_character(path)
		if character == null:
			continue

		var char_name := character.display_name
		if char_name.length() < 5:
			suffixes.append(char_name)

		for nickname in character.nicknames:
			var nick := str(nickname).strip_edges()
			if not nick.is_empty():
				suffixes.append(nick)

		var variant := _first_variant_label(character)
		if not variant.is_empty() and variant.split(" ")[0].length() < 5:
			suffixes.append(variant.split(" ")[0])

		var desc: String = character.extra_config.get("description", "")
		if desc.is_empty():
			continue

		var parts_de := desc.split("的")
		if not parts_de.is_empty() and parts_de[0].length() <= 6:
			prefixes.append(parts_de[0] + "的")

		var parts_zhi := desc.split("之")
		if not parts_zhi.is_empty() and parts_zhi[0].length() <= 6:
			prefixes.append(parts_zhi[0] + "之")

	var prefix := _pick_random(prefixes)
	var suffix := _pick_random(suffixes)
	if prefix.is_empty() and suffix.is_empty():
		return "访客%03d" % (randi() % 1000)
	return prefix + suffix


func _first_variant_label(character: DialogicCharacter) -> String:
	var image_path := character.get_portrait_image_path()
	if image_path.is_empty():
		return ""
	return image_path.get_file().get_basename()


func _pick_random(items: Array[String]) -> String:
	if items.is_empty():
		return ""
	return items[randi() % items.size()]
