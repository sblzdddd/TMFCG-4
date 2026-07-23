# GdUnit TestSuite
class_name TrickResolutionTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func _state(uids: Array[String]) -> GameState:
	var players: Array[PlayerState] = []
	for uid in uids:
		var player := PlayerState.new(PlayerId.from_string(uid))
		player.hand.add_cards([Card.new(Rank.THREE, Suit.HEARTS)])
		players.append(player)
	return GameState.new(Deck.empty(), players)


func test_end_when_passes_wrap_to_active_winner() -> void:
	var state := _state(["p1", "p2", "p3"])
	state.trick_winner_id = PlayerId.from_string("p1")
	state.passes_count = 2
	var order := PlayerOrder.new(["p1", "p2", "p3"])
	assert_that(TrickResolution.should_end_by_passes(state, order, "p1")).is_true()
	assert_that(TrickResolution.should_end_by_passes(state, order, "p2")).is_false()


func test_end_when_placed_winner_and_all_remaining_passed() -> void:
	var state := _state(["p1", "p2", "p3"])
	state.trick_winner_id = PlayerId.from_string("p1")
	state.placements.append(PlayerId.from_string("p1"))
	state.current_trick_combo = SingleCombination.new(
		[Card.new(Rank.NINE, Suit.HEARTS)],
		CardEnums.rank_weight(Rank.NINE),
	)
	state.passes_count = 2
	var order := PlayerOrder.new(["p1", "p2", "p3"])
	# Next active after last passer is p2 (winner skipped); still ends.
	assert_that(TrickResolution.should_end_by_passes(state, order, "p2")).is_true()
	state.passes_count = 1
	assert_that(TrickResolution.should_end_by_passes(state, order, "p2")).is_false()


func test_end_round_clears_combo_for_placed_winner_lead() -> void:
	var state := _state(["p1", "p2", "p3"])
	state.trick_winner_id = PlayerId.from_string("p1")
	state.placements.append(PlayerId.from_string("p1"))
	state.current_trick_combo = SingleCombination.new(
		[Card.new(Rank.KING, Suit.SPADES)],
		CardEnums.rank_weight(Rank.KING),
	)
	state.passes_count = 2
	state.end_round()
	assert_that(state.current_trick_combo).is_null()
	assert_that(state.passes_count).is_equal(0)
	assert_str(state.trick_winner_id.value).is_equal("p1")
	var order := PlayerOrder.new(["p1", "p2", "p3"])
	assert_str(PlacementTracker.next_active_after(state, order, "p1")).is_equal("p2")
