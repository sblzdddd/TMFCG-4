extends RefCounted

const DESCRIPTION_PREFIX := "description="


static func get_card_description(character: DialogicCharacter) -> String:
	return parse_structured_description(character.description)


static func get_english_display_name(character: DialogicCharacter) -> String:
	if ProjectSettings.get_setting("dialogic/translation/enabled", false):
		var translation_key := character.get_property_translation_key(
			DialogicCharacter.TranslatedProperties.NAME
		)
		var en_translation := TranslationServer.get_translation_object("en")
		if en_translation:
			var english_name := en_translation.get_message(translation_key)
			if not english_name.is_empty() and english_name != translation_key:
				return english_name

	if not character.display_name.is_empty():
		return character.display_name
	return character.get_character_name()


static func parse_structured_description(raw: String) -> String:
	var index := raw.find(DESCRIPTION_PREFIX)
	if index == -1:
		return raw.strip_edges()
	return raw.substr(index + DESCRIPTION_PREFIX.length()).strip_edges()
