# GdUnit TestSuite
class_name PlacementTrackerTestSuite
extends GdUnitTestSuite


func _state_with_players(uids: Array[String]) -> GameState:
	var players: Array[PlayerState] = []
	for uid in uids:
		var player := PlayerState.new(PlayerId.from_string(uid))
		player.hand.add_cards([Card.new(CardEnums.Rank.THREE, CardEnums.Suit.HEARTS)])
		players.append(player)
	return GameState.new(Deck.empty(), players)


func test_place_when_hand_empty_and_deck_empty() -> void:
	var state := _state_with_players(["a", "b"])
	state.current_phase = MatchPhase.Phase.END_GAME_PLAY
	state.get_player_hand(PlayerId.from_string("a")).remove_cards(
		state.get_player_hand(PlayerId.from_string("a")).get_all_cards()
	)
	assert_that(PlacementTracker.place_if_needed(state, "a", true)).is_true()
	assert_that(PlacementTracker.is_placed(state, "a")).is_true()
	assert_that(state.placements.size()).is_equal(1)


func test_finalize_places_last_active_and_signals_done() -> void:
	var state := _state_with_players(["a", "b"])
	state.placements.append(PlayerId.from_string("a"))
	var order := PlayerOrder.new(["a", "b"])
	assert_that(PlacementTracker.finalize_if_done(state, order)).is_true()
	assert_that(PlacementTracker.is_placed(state, "b")).is_true()
	assert_that(state.placements.size()).is_equal(2)


func test_next_active_skips_placed() -> void:
	var state := _state_with_players(["a", "b", "c"])
	state.placements.append(PlayerId.from_string("b"))
	var order := PlayerOrder.new(["a", "b", "c"])
	assert_str(PlacementTracker.next_active_after(state, order, "a")).is_equal("c")
