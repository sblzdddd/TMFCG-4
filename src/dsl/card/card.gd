class_name Card
extends RefCounted

const Suit := CardEnums.Suit
const Rank := CardEnums.Rank

var rank: Rank
var suit: Suit
var instance_id: CardInstanceId


func _init(
	p_rank: Rank,
	p_suit: Suit,
	p_instance_id: CardInstanceId = null,
) -> void:
	rank = p_rank
	suit = p_suit
	instance_id = p_instance_id if p_instance_id != null else CardInstanceId.new()


func is_greater_than(other: Card) -> bool:
	return CardEnums.rank_weight(rank) > CardEnums.rank_weight(other.rank)


func duplicate_card() -> Card:
	return Card.new(rank, suit, CardInstanceId.from_string(instance_id.value))


func to_dict() -> Dictionary:
	return {
		"rank": Rank.find_key(rank),
		"suit": Suit.find_key(suit),
		"instanceId": instance_id.value,
	}


static func from_dict(data: Dictionary) -> Card:
	return Card.new(
		CardEnums.rank_from_name(str(data.get("rank", ""))),
		CardEnums.suit_from_name(str(data.get("suit", ""))),
		CardInstanceId.from_string(str(data.get("instanceId", ""))),
	)


static func from_card_data(data: CardData) -> Card:
	return data.to_card()


func _to_string() -> String:
	return "%s%s" % [CardEnums.suit_display_name(suit), CardEnums.rank_display_name(rank)]
