# GdUnit TestSuite
class_name SoftDrawTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func _player(uid: String, hand_size: int) -> PlayerState:
	var player := PlayerState.new(PlayerId.from_string(uid))
	var cards: Array[Card] = []
	for _i in hand_size:
		cards.append(Card.new(Rank.THREE, Suit.HEARTS))
	player.hand.add_cards(cards)
	return player


func test_draw_uids_start_from_winner() -> void:
	var order := PlayerOrder.new(["p1", "p2", "p3"])
	assert_array(SoftDraw.draw_uids(order, "p2")).contains_exactly(["p2", "p3", "p1"])
	assert_array(SoftDraw.draw_uids(order, "")).contains_exactly(["p1", "p2", "p3"])
	assert_array(SoftDraw.draw_uids(order, "missing")).contains_exactly(["p1", "p2", "p3"])


func test_soft_fill_winner_draws_before_earlier_seats() -> void:
	# p1 needs 2, p2 (winner) needs 2; only 3 cards left → p2 gets 2, p1 gets 1.
	var p1 := _player("p1", 3)
	var p2 := _player("p2", 3)
	var deck_cards: Array[Card] = [
		Card.new(Rank.FOUR, Suit.CLUBS),
		Card.new(Rank.FIVE, Suit.CLUBS),
		Card.new(Rank.WILD, Suit.JOKERS),
	]
	var state := GameState.new(Deck.new(deck_cards), [p1, p2])
	state.trick_winner_id = PlayerId.from_string("p2")
	var order := PlayerOrder.new(["p1", "p2"])
	var drawn := SoftDraw.apply(state, order, 5)
	assert_that(drawn.has("p2")).is_true()
	assert_that((drawn["p2"] as Array).size()).is_equal(2)
	assert_that(drawn.has("p1")).is_true()
	assert_that((drawn["p1"] as Array).size()).is_equal(1)
	assert_that(p2.hand.get_size()).is_equal(5)
	assert_that(p1.hand.get_size()).is_equal(4)
	assert_that(state.deck.get_size()).is_equal(0)
