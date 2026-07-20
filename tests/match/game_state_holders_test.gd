# GdUnit TestSuite
class_name GameStateHoldersTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit
const TemporaryGraveyardType := preload(
	"res://src/dsl/card_holder/temporary_graveyard.gd"
)


func _make_state() -> GameState:
	var p1 := PlayerState.new(PlayerId.from_string("p1"))
	var p2 := PlayerState.new(PlayerId.from_string("p2"))
	var deck := Deck.new([
		Card.new(Rank.THREE, Suit.HEARTS),
		Card.new(Rank.FOUR, Suit.SPADES),
		Card.new(Rank.FIVE, Suit.CLUBS),
		Card.new(Rank.SIX, Suit.DIAMONDS),
	])
	return GameState.new(deck, [p1, p2])


func test_game_state_has_holder_zones() -> void:
	var state := _make_state()
	assert_that(state.deck.get_size()).is_equal(4)
	assert_that(state.graveyard.get_size()).is_equal(0)
	assert_that(state.all_player_hands().size()).is_equal(2)
	assert_str(state.get_current_player_hand().holder_id).is_equal("p1")
	assert_str(state.players[0].temporary_graveyard.holder_id).is_equal(
		TemporaryGraveyardType.holder_id_for_player_uid("p1")
	)
	assert_that(state.all_card_holders().size()).is_equal(6)


func test_transfer_deck_to_hand_to_graveyard() -> void:
	var state := _make_state()
	var hand := state.get_player_hand(PlayerId.from_string("p1"))
	var card := state.deck.get_card(0)
	state.transfer_cards(state.deck, hand, [card])
	assert_that(state.deck.get_size()).is_equal(3)
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
	assert_that(restored.deck.get_size()).is_equal(3)
	assert_that(restored.get_player_hand(PlayerId.from_string("p2")).get_size()).is_equal(1)
	assert_bool(restored.get_player_hand(PlayerId.from_string("p2")).get_card(0).hidden).is_true()


func test_mark_hidden_hand_transfer_restricts_visibility_to_owner() -> void:
	var state := _make_state()
	var player_id := PlayerId.from_string("p1")
	var hand := state.get_player_hand(player_id)
	var card := state.deck.get_card(0)
	state.transfer_cards(state.deck, hand, [card], true)
	assert_bool(card.is_public).is_false()
	assert_array(card.allowed_viewer_uids).contains_exactly(["p1"])

	var owner_hand: Dictionary = state.to_dict_for_viewer("p1")["players"][0]["hand"]
	var owner_card: Dictionary = owner_hand["cards"][0]
	assert_bool(owner_card.has("rank")).is_true()
	assert_bool(bool(owner_card["hidden"])).is_false()

	var opponent_hand: Dictionary = state.to_dict_for_viewer("p2")["players"][0]["hand"]
	var opponent_card: Dictionary = opponent_hand["cards"][0]
	assert_bool(opponent_card.has("rank")).is_false()
	assert_bool(opponent_card.has("suit")).is_false()
	assert_bool(opponent_card.has("cardId")).is_false()
	assert_bool(opponent_card.has("allowedViewerUids")).is_false()
	assert_bool(bool(opponent_card["hidden"])).is_true()


func test_deck_projection_respects_card_policy() -> void:
	var state := _make_state()
	state.deck.get_card(0).restrict_visibility_to([])
	state.deck.get_card(1).restrict_visibility_to(["p1"])
	var p1_deck: Dictionary = state.to_dict_for_viewer("p1")["deck"]
	var outsider_deck: Dictionary = state.to_dict_for_viewer("p2")["deck"]
	assert_bool((p1_deck["cards"][0] as Dictionary).has("rank")).is_false()
	assert_bool((p1_deck["cards"][1] as Dictionary).has("rank")).is_true()
	assert_bool((outsider_deck["cards"][1] as Dictionary).has("rank")).is_false()


func test_record_play_serializes_temporary_graveyards_and_flushes_global_order() -> void:
	var state := _make_state()
	var p1 := PlayerId.from_string("p1")
	var p2 := PlayerId.from_string("p2")
	var p1_hand := state.get_player_hand(p1)
	var p2_hand := state.get_player_hand(p2)
	var first := state.deck.get_card(0)
	var second := state.deck.get_card(1)
	var third := state.deck.get_card(2)
	state.transfer_cards(state.deck, p1_hand, [first, third], true)
	state.transfer_cards(state.deck, p2_hand, [second], true)

	state.record_play(p1, [first])
	state.record_play(p2, [second])
	state.record_play(p1, [third])
	assert_array(state.play_history_instance_ids).contains_exactly([
		first.instance_id.value,
		second.instance_id.value,
		third.instance_id.value,
	])
	assert_bool(first.is_public).is_true()
	assert_that(state.get_holder(
		TemporaryGraveyardType.holder_id_for_player_uid("p1")
	)).is_same(state.players[0].temporary_graveyard)

	var restored := GameState.from_dict(state.to_dict())
	assert_that(restored.players[0].temporary_graveyard.get_size()).is_equal(2)
	assert_that(restored.players[1].temporary_graveyard.get_size()).is_equal(1)
	assert_array(restored.play_history_instance_ids).contains_exactly([
		first.instance_id.value,
		second.instance_id.value,
		third.instance_id.value,
	])

	var flushed := restored.end_round()
	assert_that(flushed.size()).is_equal(3)
	assert_array(restored.graveyard.get_all_cards().map(
		func(card: Card) -> String: return card.instance_id.value
	)).contains_exactly([
		first.instance_id.value,
		second.instance_id.value,
		third.instance_id.value,
	])
	assert_that(restored.players[0].temporary_graveyard.get_size()).is_equal(0)
	assert_that(restored.players[1].temporary_graveyard.get_size()).is_equal(0)
	assert_bool(restored.play_history_instance_ids.is_empty()).is_true()


func test_player_state_deserializes_without_temporary_graveyard() -> void:
	var restored := PlayerState.from_dict({
		"playerId": "legacy-player",
		"hand": {},
	})
	assert_that(restored.temporary_graveyard).is_not_null()
	assert_str(restored.temporary_graveyard.holder_id).is_equal(
		TemporaryGraveyardType.holder_id_for_player_uid("legacy-player")
	)
