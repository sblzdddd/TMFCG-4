class_name Card
extends RefCounted

const Suit := CardEnums.Suit
const Rank := CardEnums.Rank

var data: CardData
var instance_id: CardInstanceId
## Compatibility flag used by client projections. Authoritative visibility is
## represented by is_public and allowed_viewer_uids.
var hidden: bool = false
var is_public: bool = true
var allowed_viewer_uids: Array[String] = []

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
	p_is_public: bool = not p_hidden,
	p_allowed_viewer_uids: Array[String] = [],
) -> void:
	if p_data != null:
		data = p_data
	else:
		data = _ephemeral_card_data(p_rank, p_suit)
	instance_id = p_instance_id if p_instance_id != null else CardInstanceId.new()
	hidden = p_hidden
	is_public = p_is_public
	allowed_viewer_uids = _normalized_viewer_uids(p_allowed_viewer_uids)


static func from_data(
	p_data: CardData,
	p_instance_id: CardInstanceId = null,
	p_hidden: bool = false,
	p_is_public: bool = not p_hidden,
	p_allowed_viewer_uids: Array[String] = [],
) -> Card:
	assert(p_data != null)
	return Card.new(
		p_data.rank,
		p_data.suit,
		p_instance_id,
		p_hidden,
		p_data,
		p_is_public,
		p_allowed_viewer_uids,
	)


func is_greater_than(other: Card) -> bool:
	return CardEnums.rank_weight(rank) > CardEnums.rank_weight(other.rank)


func duplicate_card() -> Card:
	var duplicated_data: CardData = data.duplicate(true) as CardData if data != null else null
	return Card.from_data(
		duplicated_data if duplicated_data != null else _ephemeral_card_data(rank, suit),
		CardInstanceId.from_string(instance_id.value),
		hidden,
		is_public,
		allowed_viewer_uids,
	)


func can_be_viewed_by(viewer_uid: String) -> bool:
	return is_public or allowed_viewer_uids.has(viewer_uid)


func make_public() -> void:
	is_public = true
	allowed_viewer_uids.clear()
	hidden = false


func restrict_visibility_to(viewer_uids: Array[String]) -> void:
	is_public = false
	allowed_viewer_uids = _normalized_viewer_uids(viewer_uids)
	hidden = true


func to_dict() -> Dictionary:
	return {
		"rank": Rank.find_key(rank),
		"suit": Suit.find_key(suit),
		"cardId": data.cardId if data != null else "card-0",
		"instanceId": instance_id.value,
		"hidden": hidden,
		"isPublic": is_public,
		"allowedViewerUids": allowed_viewer_uids.duplicate(),
	}


func to_dict_for_viewer(viewer_uid: String) -> Dictionary:
	if not can_be_viewed_by(viewer_uid):
		return {
			"instanceId": instance_id.value,
			"hidden": true,
		}
	var projection := to_dict()
	projection["hidden"] = false
	return projection


static func from_dict(dict: Dictionary) -> Card:
	var card_data := CardData.new()
	card_data.rank = CardEnums.rank_from_name(str(dict.get("rank", "")))
	card_data.suit = CardEnums.suit_from_name(str(dict.get("suit", "")))
	card_data.cardId = str(dict.get("cardId", "card-0"))
	var legacy_hidden := bool(dict.get("hidden", false))
	var viewer_uids: Array[String] = []
	var raw_viewer_uids: Variant = dict.get("allowedViewerUids", [])
	if raw_viewer_uids is Array:
		for uid in raw_viewer_uids:
			var uid_value := str(uid)
			if not uid_value.is_empty() and not viewer_uids.has(uid_value):
				viewer_uids.append(uid_value)
	return Card.from_data(
		card_data,
		CardInstanceId.from_string(str(dict.get("instanceId", ""))),
		legacy_hidden,
		bool(dict.get("isPublic", not legacy_hidden)),
		viewer_uids,
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


static func _normalized_viewer_uids(viewer_uids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for uid in viewer_uids:
		if not uid.is_empty() and not result.has(uid):
			result.append(uid)
	return result
