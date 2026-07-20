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
	assert_dict(json_dict).contains_keys([
		"rank",
		"suit",
		"cardId",
		"instanceId",
		"hidden",
		"isPublic",
		"allowedViewerUids",
	])
	assert_str(str(json_dict["rank"])).is_equal("THREE")
	assert_str(str(json_dict["suit"])).is_equal("HEARTS")
	assert_str(str(json_dict["instanceId"])).is_equal("0fe19e96-6cc5-4c04-b7b3-84a507e65262")
	assert_bool(bool(json_dict["hidden"])).is_true()
	assert_bool(bool(json_dict["isPublic"])).is_false()


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
	assert_bool(card.is_public).is_false()


func test_card_from_data_preserves_card_data() -> void:
	var card_data := CardData.new()
	card_data.rank = Rank.ACE
	card_data.suit = Suit.SPADES
	card_data.cardId = "ace-spades"
	var card := Card.from_data(card_data, null, false)
	assert_that(card.data).is_same(card_data)
	assert_that(card.rank).is_equal(Rank.ACE)
	assert_bool(card.hidden).is_false()


func test_visibility_policy_round_trip_and_viewer_projection() -> void:
	var card := Card.new(
		Rank.KING,
		Suit.DIAMONDS,
		CardInstanceId.from_string("private-card"),
	)
	card.restrict_visibility_to(["owner", "spectator"])
	var restored := Card.from_dict(card.to_dict())
	assert_bool(restored.is_public).is_false()
	assert_array(restored.allowed_viewer_uids).contains_exactly(["owner", "spectator"])

	var owner_projection := restored.to_dict_for_viewer("owner")
	assert_that(owner_projection["rank"]).is_equal("KING")
	assert_that(owner_projection["suit"]).is_equal("DIAMONDS")
	assert_bool(bool(owner_projection["hidden"])).is_false()

	var opponent_projection := restored.to_dict_for_viewer("opponent")
	assert_that(opponent_projection.size()).is_equal(2)
	assert_str(str(opponent_projection["instanceId"])).is_equal("private-card")
	assert_bool(bool(opponent_projection["hidden"])).is_true()
	for secret_key in ["rank", "suit", "cardId", "isPublic", "allowedViewerUids"]:
		assert_bool(opponent_projection.has(secret_key)).is_false()


func test_public_card_is_visible_to_any_viewer() -> void:
	var card := Card.new(Rank.ACE, Suit.SPADES)
	var projection := card.to_dict_for_viewer("any-player")
	assert_that(projection["rank"]).is_equal("ACE")
	assert_that(projection["suit"]).is_equal("SPADES")
	assert_bool(bool(projection["hidden"])).is_false()
