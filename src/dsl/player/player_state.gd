class_name PlayerState
extends RefCounted

const TemporaryGraveyardType := preload(
	"res://src/dsl/card_holder/temporary_graveyard.gd"
)

var player_id: PlayerId
var hand: PlayerHand
var temporary_graveyard: TemporaryGraveyardType


func _init(
	p_player_id: PlayerId,
	p_hand: PlayerHand = null,
	p_temporary_graveyard: TemporaryGraveyardType = null,
) -> void:
	player_id = p_player_id
	hand = p_hand if p_hand != null else PlayerHand.new(p_player_id)
	temporary_graveyard = (
		p_temporary_graveyard
		if p_temporary_graveyard != null
		else TemporaryGraveyardType.new(p_player_id)
	)


func to_dict() -> Dictionary:
	return {
		"playerId": player_id.value if player_id != null else "",
		"hand": hand.to_dict() if hand != null else {},
		"temporaryGraveyard": (
			temporary_graveyard.to_dict()
			if temporary_graveyard != null
			else {}
		),
	}


func to_dict_for_viewer(viewer_uid: String) -> Dictionary:
	return {
		"playerId": player_id.value if player_id != null else "",
		"hand": (
			hand.to_dict_for_viewer(viewer_uid)
			if hand != null
			else {}
		),
		"temporaryGraveyard": (
			temporary_graveyard.to_dict_for_viewer(viewer_uid)
			if temporary_graveyard != null
			else {}
		),
	}


static func from_dict(dict: Dictionary) -> PlayerState:
	var player_id := PlayerId.from_string(str(dict.get("playerId", "")))
	var hand_dict: Variant = dict.get("hand", {})
	var hand: PlayerHand
	if hand_dict is Dictionary and not (hand_dict as Dictionary).is_empty():
		hand = PlayerHand.from_dict(hand_dict)
	else:
		hand = PlayerHand.new(player_id)
	var temporary_dict: Variant = dict.get("temporaryGraveyard", {})
	var temporary_graveyard: TemporaryGraveyardType
	if temporary_dict is Dictionary and not (temporary_dict as Dictionary).is_empty():
		var temporary_holder_id := str(temporary_dict.get("holderId", ""))
		var temporary_player_uid := temporary_holder_id.trim_prefix(
			TemporaryGraveyardType.HOLDER_ID_PREFIX
		)
		if temporary_player_uid.is_empty():
			temporary_player_uid = player_id.value
		temporary_graveyard = TemporaryGraveyardType.new(
			PlayerId.from_string(temporary_player_uid),
			CardHolder.cards_from_dict(temporary_dict),
		)
	else:
		temporary_graveyard = TemporaryGraveyardType.new(player_id)
	return PlayerState.new(player_id, hand, temporary_graveyard)
