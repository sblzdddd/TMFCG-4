class_name PlayerHand
extends CardHolder


func _init(p_player_id: PlayerId = null, p_cards: Array[Card] = []) -> void:
	var id_value := p_player_id.value if p_player_id != null else ""
	super._init(Kind.PLAYER_HAND, id_value, p_cards)


static func from_dict(dict: Dictionary) -> PlayerHand:
	var player_id := PlayerId.from_string(str(dict.get("holderId", "")))
	return PlayerHand.new(player_id, CardHolder.cards_from_dict(dict))


func to_dict_for_viewer(viewer_uid: String) -> Dictionary:
	if viewer_uid != holder_id:
		return super.to_dict_for_viewer(viewer_uid)
	var card_dicts: Array = []
	for card in _cards:
		var card_dict := card.to_dict()
		card_dict["hidden"] = false
		card_dicts.append(card_dict)
	return {
		"kind": Kind.find_key(kind),
		"holderId": holder_id,
		"cards": card_dicts,
	}
