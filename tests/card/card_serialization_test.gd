# GdUnit TestSuite
class_name CardSerializationTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_card_serialization() -> void:
	var card := Card.new(
		Rank.THREE,
		Suit.HEARTS,
		CardInstanceId.from_string("0fe19e96-6cc5-4c04-b7b3-84a507e65262"),
		true,
	)
	var json_dict := card.to_dict()
	assert_dict(json_dict).contains_keys(["rank", "suit", "cardId", "instanceId", "hidden"])
	assert_str(str(json_dict["rank"])).is_equal("THREE")
	assert_str(str(json_dict["suit"])).is_equal("HEARTS")
	assert_str(str(json_dict["instanceId"])).is_equal("0fe19e96-6cc5-4c04-b7b3-84a507e65262")
	assert_bool(bool(json_dict["hidden"])).is_true()


func test_card_deserialization() -> void:
	var card := Card.from_dict({
		"rank": "THREE",
		"suit": "HEARTS",
		"cardId": "card-3h",
		"instanceId": "0fe19e96-6cc5-4c04-b7b3-84a507e65262",
		"hidden": true,
	})
	assert_that(card.rank).is_equal(Rank.THREE)
	assert_that(card.suit).is_equal(Suit.HEARTS)
	assert_str(card.data.cardId).is_equal("card-3h")
	assert_str(card.instance_id.value).is_equal("0fe19e96-6cc5-4c04-b7b3-84a507e65262")
	assert_bool(card.hidden).is_true()


func test_card_from_data_preserves_card_data() -> void:
	var card_data := CardData.new()
	card_data.rank = Rank.ACE
	card_data.suit = Suit.SPADES
	card_data.cardId = "ace-spades"
	var card := Card.from_data(card_data, null, false)
	assert_that(card.data).is_same(card_data)
	assert_that(card.rank).is_equal(Rank.ACE)
	assert_bool(card.hidden).is_false()
