# GdUnit TestSuite
class_name CardCombinationTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_single_compares_by_power_when_same_type() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var lower := SingleCombination.new([card], CardEnums.rank_weight(Rank.THREE))
	var higher := SingleCombination.new([card], CardEnums.rank_weight(Rank.FIVE))

	assert_that(higher.compare_to(lower)).is_equal(2)
	assert_that(lower.compare_to(higher)).is_equal(-2)


func test_pair_with_same_power_compares_as_equal() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var left := PairCombination.new([card], CardEnums.rank_weight(Rank.TEN))
	var right := PairCombination.new([card], CardEnums.rank_weight(Rank.TEN))

	assert_that(left.compare_to(right)).is_equal(0)


func test_different_non_bomb_combination_types_are_not_comparable() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var single := SingleCombination.new([card], CardEnums.rank_weight(Rank.KING))
	var pair := PairCombination.new([card], CardEnums.rank_weight(Rank.THREE))
	var straight := StraightCombination.new([card], CardEnums.rank_weight(Rank.FOUR))

	assert_that(single.compare_to(pair)).is_equal(-1)
	assert_that(pair.compare_to(straight)).is_equal(-1)


func test_bomb_beats_any_non_bomb_and_returns_bomb_power() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var bomb := BombCombination.new([card], CardEnums.rank_weight(Rank.SEVEN), 3)
	var single := SingleCombination.new([card], CardEnums.rank_weight(Rank.TWO))

	assert_that(bomb.compare_to(single)).is_equal(CardEnums.rank_weight(Rank.SEVEN))


func test_non_bomb_loses_to_bomb() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var pair := PairCombination.new([card], CardEnums.rank_weight(Rank.TWO))
	var bomb := BombCombination.new([card], CardEnums.rank_weight(Rank.THREE), 3)

	assert_that(pair.compare_to(bomb)).is_equal(-1)


func test_bomb_compares_by_power_against_another_bomb() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var lower := BombCombination.new([card], CardEnums.rank_weight(Rank.QUEEN), 3)
	var higher := BombCombination.new([card], CardEnums.rank_weight(Rank.ACE), 4)

	assert_that(higher.compare_to(lower)).is_equal(9)
	assert_that(lower.compare_to(higher)).is_equal(-9)


func test_shorter_straight_cannot_beat_longer_straight() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var three_len := StraightCombination.new(
		[card, card, card], CardEnums.rank_weight(Rank.THREE), 3
	)
	var two_len := StraightCombination.new(
		[card, card], CardEnums.rank_weight(Rank.JACK), 2
	)

	assert_that(two_len.compare_to(three_len)).is_equal(-1)
	assert_that(three_len.compare_to(two_len)).is_equal(1)


func test_same_length_straights_compare_by_power() -> void:
	var card := Card.new(Rank.THREE, Suit.HEARTS)
	var lower := StraightCombination.new([card, card], CardEnums.rank_weight(Rank.SEVEN), 2)
	var higher := StraightCombination.new([card, card], CardEnums.rank_weight(Rank.JACK), 2)

	assert_that(higher.compare_to(lower)).is_equal(
		CardEnums.rank_weight(Rank.JACK) - CardEnums.rank_weight(Rank.SEVEN)
	)
