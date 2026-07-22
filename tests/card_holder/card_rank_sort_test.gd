# GdUnit TestSuite
class_name CardRankSortTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_sort_cards_by_rank_then_suit() -> void:
	var cards: Array[Card] = [
		Card.new(Rank.KING, Suit.HEARTS),
		Card.new(Rank.THREE, Suit.SPADES),
		Card.new(Rank.THREE, Suit.CLUBS),
		Card.new(Rank.ACE, Suit.DIAMONDS),
	]
	CardRankSort.sort_cards(cards)
	assert_that(cards[0].rank).is_equal(Rank.THREE)
	assert_that(cards[0].suit).is_equal(Suit.CLUBS)
	assert_that(cards[1].rank).is_equal(Rank.THREE)
	assert_that(cards[2].rank).is_equal(Rank.KING)
	assert_that(cards[3].rank).is_equal(Rank.ACE)


func test_hand_sorts_after_transfer_deck_does_not() -> void:
	var deck := Deck.new([
		Card.new(Rank.KING, Suit.HEARTS),
		Card.new(Rank.THREE, Suit.SPADES),
	])
	var hand := PlayerHand.new(PlayerId.from_string("p1"))
	var first := deck.get_card(0)
	deck.transfer_to(hand, [first])
	assert_that(hand.get_card(0).rank).is_equal(Rank.KING)
	# Deck order of remaining card unchanged (no sort on deck).
	assert_that(deck.get_card(0).rank).is_equal(Rank.THREE)
	deck.transfer_to(hand, [deck.get_card(0)])
	assert_that(hand.get_card(0).rank).is_equal(Rank.THREE)
	assert_that(hand.get_card(1).rank).is_equal(Rank.KING)


func test_equal_rank_and_suit_sort_by_instance_id() -> void:
	var later := Card.new(
		Rank.FIVE, Suit.HEARTS, CardInstanceId.from_string("card-z")
	)
	var earlier := Card.new(
		Rank.FIVE, Suit.HEARTS, CardInstanceId.from_string("card-a")
	)
	var cards: Array[Card] = [later, earlier]
	CardRankSort.sort_cards(cards)
	assert_array(cards.map(
		func(card: Card) -> String: return card.instance_id.value
	)).contains_exactly(["card-a", "card-z"])


func test_wild_sorts_by_its_printed_rank() -> void:
	var cards: Array[Card] = [
		Card.new(Rank.KING, Suit.CLUBS),
		Card.new(Rank.WILD, Suit.HEARTS),
		Card.new(Rank.THREE, Suit.SPADES),
	]
	CardRankSort.sort_cards(cards, Rank.FIVE)
	assert_array(cards.map(
		func(card: Card) -> CardEnums.Rank: return card.rank
	)).contains_exactly([Rank.THREE, Rank.WILD, Rank.KING])
