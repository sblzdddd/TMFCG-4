class_name PlayerState
extends RefCounted

var player_id: PlayerId
var hand: PlayerHand


func _init(p_player_id: PlayerId, p_hand: PlayerHand = null) -> void:
	player_id = p_player_id
	hand = p_hand if p_hand != null else PlayerHand.new(p_player_id)


func to_dict() -> Dictionary:
	return {
		"playerId": player_id.value if player_id != null else "",
		"hand": hand.to_dict() if hand != null else {},
	}


static func from_dict(dict: Dictionary) -> PlayerState:
	var player_id := PlayerId.from_string(str(dict.get("playerId", "")))
	var hand_dict: Variant = dict.get("hand", {})
	var hand: PlayerHand
	if hand_dict is Dictionary and not (hand_dict as Dictionary).is_empty():
		hand = PlayerHand.from_dict(hand_dict)
	else:
		hand = PlayerHand.new(player_id)
	return PlayerState.new(player_id, hand)
