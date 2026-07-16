class_name PlayerHand
extends CardHolder


func _init(p_player_id: PlayerId = null, p_cards: Array[Card] = []) -> void:
	var id_value := p_player_id.value if p_player_id != null else ""
	super._init(Kind.PLAYER_HAND, id_value, p_cards)


static func from_dict(dict: Dictionary) -> PlayerHand:
	var player_id := PlayerId.from_string(str(dict.get("holderId", "")))
	return PlayerHand.new(player_id, CardHolder.cards_from_dict(dict))
