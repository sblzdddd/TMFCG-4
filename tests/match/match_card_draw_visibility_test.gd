# GdUnit TestSuite
class_name MatchCardDrawVisibilityTestSuite
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
		Card.new(Rank.SIX, Suit.DIAMONDS),
		Card.new(Rank.SEVEN, Suit.HEARTS),
		Card.new(Rank.EIGHT, Suit.SPADES),
	])
	for card in deck.get_all_cards():
		card.restrict_visibility_to([])
	return GameState.new(deck, [p1, p2])


func test_draw_via_transfer_hides_from_opponent() -> void:
	var state := _make_state()
	var hand := state.get_player_hand(PlayerId.from_string("p1"))
	var selected: Array[Card] = []
	for i in 2:
		selected.append(state.deck.get_card(i))
	var moved := state.transfer_cards(state.deck, hand, selected, true)
	assert_that(moved.size()).is_equal(2)
	assert_that(hand.get_size()).is_equal(2)
	assert_that(state.deck.get_size()).is_equal(4)

	var owner_proj := state.to_dict_for_viewer("p1")
	var owner_cards: Array = owner_proj["players"][0]["hand"]["cards"]
	assert_that(owner_cards.size()).is_equal(2)
	assert_bool((owner_cards[0] as Dictionary).has("rank")).is_true()
	assert_bool(bool((owner_cards[0] as Dictionary)["hidden"])).is_false()

	var opp_proj := state.to_dict_for_viewer("p2")
	var opp_cards: Array = opp_proj["players"][0]["hand"]["cards"]
	assert_that(opp_cards.size()).is_equal(2)
	assert_bool((opp_cards[0] as Dictionary).has("rank")).is_false()
	assert_bool(bool((opp_cards[0] as Dictionary)["hidden"])).is_true()


func test_soft_draw_target_fills_toward_five() -> void:
	var state := _make_state()
	var hand := state.get_player_hand(PlayerId.from_string("p1"))
	var need := maxi(0, 5 - hand.get_size())
	var n := mini(need, state.deck.get_size())
	var selected: Array[Card] = []
	for i in n:
		selected.append(state.deck.get_card(i))
	state.transfer_cards(state.deck, hand, selected, true)
	assert_that(hand.get_size()).is_equal(5)


func test_filtered_snapshot_round_trip_keeps_hidden_hands() -> void:
	var state := _make_state()
	var hand := state.get_player_hand(PlayerId.from_string("p1"))
	state.transfer_cards(state.deck, hand, [state.deck.get_card(0)], true)
	var filtered := state.to_dict_for_viewer("p2")
	var restored := GameState.from_dict(filtered)
	var restored_hand := restored.get_player_hand(PlayerId.from_string("p1"))
	assert_that(restored_hand.get_size()).is_equal(1)
	var card := restored_hand.get_card(0)
	assert_bool(card.hidden).is_true()
	assert_bool(card.can_be_viewed_by("p2")).is_false()
