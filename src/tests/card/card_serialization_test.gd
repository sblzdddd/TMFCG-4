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
	)
	var json_dict := card.to_dict()
	assert_dict(json_dict).is_equal({
		"rank": "THREE",
		"suit": "HEARTS",
		"instanceId": "0fe19e96-6cc5-4c04-b7b3-84a507e65262",
	})


func test_card_deserialization() -> void:
	var card := Card.from_dict({
		"rank": "THREE",
		"suit": "HEARTS",
		"instanceId": "0fe19e96-6cc5-4c04-b7b3-84a507e65262",
	})
	assert_that(card.rank).is_equal(Rank.THREE)
	assert_that(card.suit).is_equal(Suit.HEARTS)
	assert_str(card.instance_id.value).is_equal("0fe19e96-6cc5-4c04-b7b3-84a507e65262")
