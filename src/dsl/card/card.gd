class_name Card
extends RefCounted

const Suit := CardEnums.Suit
const Rank := CardEnums.Rank

var data: CardData
var instance_id: CardInstanceId
var hidden: bool = false

var rank: Rank:
	get:
		return data.rank if data != null else Rank.NONE

var suit: Suit:
	get:
		return data.suit if data != null else Suit.CLUBS


func _init(
	p_rank: Rank = Rank.NONE,
	p_suit: Suit = Suit.CLUBS,
	p_instance_id: CardInstanceId = null,
	p_hidden: bool = false,
	p_data: CardData = null,
) -> void:
	if p_data != null:
		data = p_data
	else:
		data = _ephemeral_card_data(p_rank, p_suit)
	instance_id = p_instance_id if p_instance_id != null else CardInstanceId.new()
	hidden = p_hidden


static func from_data(
	p_data: CardData,
	p_instance_id: CardInstanceId = null,
	p_hidden: bool = false,
) -> Card:
	assert(p_data != null)
	return Card.new(p_data.rank, p_data.suit, p_instance_id, p_hidden, p_data)


func is_greater_than(other: Card) -> bool:
	return CardEnums.rank_weight(rank) > CardEnums.rank_weight(other.rank)


func duplicate_card() -> Card:
	var duplicated_data: CardData = data.duplicate(true) as CardData if data != null else null
	return Card.from_data(
		duplicated_data if duplicated_data != null else _ephemeral_card_data(rank, suit),
		CardInstanceId.from_string(instance_id.value),
		hidden,
	)


func to_dict() -> Dictionary:
	return {
		"rank": Rank.find_key(rank),
		"suit": Suit.find_key(suit),
		"cardId": data.cardId if data != null else "card-0",
		"instanceId": instance_id.value,
		"hidden": hidden,
	}


static func from_dict(dict: Dictionary) -> Card:
	var card_data := CardData.new()
	card_data.rank = CardEnums.rank_from_name(str(dict.get("rank", "")))
	card_data.suit = CardEnums.suit_from_name(str(dict.get("suit", "")))
	card_data.cardId = str(dict.get("cardId", "card-0"))
	return Card.from_data(
		card_data,
		CardInstanceId.from_string(str(dict.get("instanceId", ""))),
		bool(dict.get("hidden", false)),
	)


static func from_card_data(card_data: CardData) -> Card:
	return card_data.to_card()


func _to_string() -> String:
	return "%s%s" % [CardEnums.suit_display_name(suit), CardEnums.rank_display_name(rank)]


static func _ephemeral_card_data(p_rank: Rank, p_suit: Suit) -> CardData:
	var card_data := CardData.new()
	card_data.rank = p_rank
	card_data.suit = p_suit
	card_data.cardId = "ephemeral-%s-%s" % [Suit.find_key(p_suit), Rank.find_key(p_rank)]
	return card_data
