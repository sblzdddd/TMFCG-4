class_name TemporaryGraveyard
extends CardHolder

const HOLDER_ID_PREFIX := "temporary_graveyard:"


func _init(p_player_id: PlayerId = null, p_cards: Array[Card] = []) -> void:
	var player_uid := p_player_id.value if p_player_id != null else ""
	super._init(Kind.TEMPORARY_GRAVEYARD, holder_id_for_player_uid(player_uid), p_cards)


static func holder_id_for_player_uid(player_uid: String) -> String:
	return HOLDER_ID_PREFIX + player_uid


static func from_dict(dict: Dictionary) -> TemporaryGraveyard:
	var raw_holder_id := str(dict.get("holderId", ""))
	var player_uid := raw_holder_id.trim_prefix(HOLDER_ID_PREFIX)
	return TemporaryGraveyard.new(
		PlayerId.from_string(player_uid),
		CardHolder.cards_from_dict(dict),
	)
