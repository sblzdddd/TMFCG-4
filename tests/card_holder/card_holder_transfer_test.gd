# GdUnit TestSuite
class_name CardHolderTransferTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_transfer_moves_cards_between_holders() -> void:
	var deck := Deck.new([
		Card.new(Rank.THREE, Suit.HEARTS),
		Card.new(Rank.FOUR, Suit.SPADES),
	])
	var hand := PlayerHand.new(PlayerId.from_string("p1"))
	var to_move: Array[Card] = [deck.get_card(0)]
	var moved := deck.transfer_to(hand, to_move)
	assert_that(moved.size()).is_equal(1)
	assert_that(deck.get_size()).is_equal(1)
	assert_that(hand.get_size()).is_equal(1)
	assert_that(hand.get_card(0).rank).is_equal(Rank.THREE)


func test_transfer_can_mark_hidden() -> void:
	var deck := Deck.new([Card.new(Rank.ACE, Suit.CLUBS)])
	var graveyard := Graveyard.new()
	var card := deck.get_card(0)
	assert_bool(card.hidden).is_false()
	deck.transfer_to(graveyard, [card], true)
	assert_bool(card.hidden).is_true()
	assert_that(graveyard.get_size()).is_equal(1)


func test_transfer_emits_signals_on_both_holders() -> void:
	var deck := Deck.new([Card.new(Rank.FIVE, Suit.DIAMONDS)])
	var hand := PlayerHand.new(PlayerId.from_string("p2"))
	var from_events: Array = []
	var to_events: Array = []
	deck.cards_transferred.connect(
		func(from: CardHolder, to: CardHolder, cards: Array, mark_hidden: bool, ignore_passives: bool) -> void:
			from_events.append([from, to, cards, mark_hidden, ignore_passives])
	)
	hand.cards_transferred.connect(
		func(from: CardHolder, to: CardHolder, cards: Array, mark_hidden: bool, ignore_passives: bool) -> void:
			to_events.append([from, to, cards, mark_hidden, ignore_passives])
	)
	deck.transfer_to(hand, [deck.get_card(0)], false, true)
	assert_that(from_events.size()).is_equal(1)
	assert_that(to_events.size()).is_equal(1)
	assert_bool(bool(from_events[0][4])).is_true()


func test_holder_serialization_round_trip() -> void:
	var hand := PlayerHand.new(
		PlayerId.from_string("player-a"),
		[Card.new(Rank.SEVEN, Suit.HEARTS, null, true)],
	)
	var restored := PlayerHand.from_dict(hand.to_dict())
	assert_str(restored.holder_id).is_equal("player-a")
	assert_that(restored.kind).is_equal(CardHolder.Kind.PLAYER_HAND)
	assert_that(restored.get_size()).is_equal(1)
	assert_bool(restored.get_card(0).hidden).is_true()
	assert_that(restored.get_card(0).rank).is_equal(Rank.SEVEN)
