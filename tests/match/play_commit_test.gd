# GdUnit TestSuite
class_name PlayCommitTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_commit_sets_trick_combo_and_winner() -> void:
	var p1 := PlayerState.new(PlayerId.from_string("p1"))
	var card := Card.new(Rank.NINE, Suit.HEARTS)
	p1.hand.add_cards([card])
	var state := GameState.new(Deck.empty(), [p1])
	assert_that(PlayCommit.apply(state, "p1", [card])).is_true()
	assert_that(state.current_trick_combo).is_instanceof(SingleCombination)
	assert_str(state.trick_winner_id.value).is_equal("p1")
	assert_that(state.passes_count).is_equal(0)


func test_commit_rejects_non_beating_play() -> void:
	var p1 := PlayerState.new(PlayerId.from_string("p1"))
	var low := Card.new(Rank.THREE, Suit.HEARTS)
	p1.hand.add_cards([low])
	var state := GameState.new(Deck.empty(), [p1])
	state.current_trick_combo = SingleCombination.new(
		[Card.new(Rank.KING, Suit.SPADES)],
		CardEnums.rank_weight(Rank.KING),
	)
	assert_that(PlayCommit.apply(state, "p1", [low])).is_false()
	assert_that(p1.hand.get_size()).is_equal(1)
