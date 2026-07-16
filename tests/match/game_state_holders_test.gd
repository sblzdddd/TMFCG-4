# GdUnit TestSuite
class_name GameStateHoldersTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func _make_state() -> GameState:
	var p1 := PlayerState.new(PlayerId.from_string("p1"))
	var p2 := PlayerState.new(PlayerId.from_string("p2"))
	var deck := Deck.new([
		Card.new(Rank.THREE, Suit.HEARTS),
		Card.new(Rank.FOUR, Suit.SPADES),
		Card.new(Rank.FIVE, Suit.CLUBS),
	])
	return GameState.new(deck, [p1, p2])


func test_game_state_has_holder_zones() -> void:
	var state := _make_state()
	assert_that(state.deck.get_size()).is_equal(3)
	assert_that(state.graveyard.get_size()).is_equal(0)
	assert_that(state.all_player_hands().size()).is_equal(2)
	assert_str(state.get_current_player_hand().holder_id).is_equal("p1")


func test_transfer_deck_to_hand_to_graveyard() -> void:
	var state := _make_state()
	var hand := state.get_player_hand(PlayerId.from_string("p1"))
	var card := state.deck.get_card(0)
	state.transfer_cards(state.deck, hand, [card])
	assert_that(state.deck.get_size()).is_equal(2)
	assert_that(hand.get_size()).is_equal(1)
	state.transfer_cards(hand, state.graveyard, [card])
	assert_that(hand.get_size()).is_equal(0)
	assert_that(state.graveyard.get_size()).is_equal(1)


func test_game_state_forwards_transfer_signal() -> void:
	var state := _make_state()
	var events: Array = []
	state.cards_transferred.connect(
		func(from: CardHolder, to: CardHolder, cards: Array, mark_hidden: bool, ignore_passives: bool) -> void:
			events.append([from.holder_id, to.holder_id, cards.size(), mark_hidden, ignore_passives])
	)
	var hand := state.get_current_player_hand()
	state.transfer_cards(state.deck, hand, [state.deck.get_card(0)], true, false)
	assert_that(events.size()).is_equal(1)
	assert_str(str(events[0][0])).is_equal("deck")
	assert_str(str(events[0][1])).is_equal("p1")
	assert_bool(bool(events[0][3])).is_true()


func test_game_state_serialization_round_trip() -> void:
	var state := _make_state()
	var hand := state.get_player_hand(PlayerId.from_string("p2"))
	state.transfer_cards(state.deck, hand, [state.deck.get_card(0)], true)
	var restored := GameState.from_dict(state.to_dict())
	assert_that(restored.deck.get_size()).is_equal(2)
	assert_that(restored.get_player_hand(PlayerId.from_string("p2")).get_size()).is_equal(1)
	assert_bool(restored.get_player_hand(PlayerId.from_string("p2")).get_card(0).hidden).is_true()
