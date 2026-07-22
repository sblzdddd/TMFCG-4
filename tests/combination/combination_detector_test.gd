# GdUnit TestSuite
class_name CombinationDetectorTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func _cards(specs: Array) -> Array[Card]:
	return TestFixtures.make_cards(specs)


func test_single_card() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.THREE, Suit.HEARTS]])
	)
	assert_that(combination).is_instanceof(SingleCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.THREE))


func test_pair_of_same_rank_cards() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.THREE, Suit.HEARTS], [Rank.THREE, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(PairCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.THREE))


func test_one_plus_one_wild() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.FIVE, Suit.HEARTS], [Rank.WILD, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(PairCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.FIVE))


func test_two_wilds() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.WILD, Suit.HEARTS], [Rank.WILD, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(PairCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.WILD))


func test_rocket_bomb() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.SMALL_JOKER, Suit.JOKERS], [Rank.BIG_JOKER, Suit.JOKERS]])
	)
	assert_that(combination).is_instanceof(BombCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.SMALL_JOKER))
	assert_that((combination as BombCombination).length).is_equal(3)


func test_two_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.THREE, Suit.HEARTS], [Rank.FOUR, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.THREE))


func test_rank_plus_wild_prefers_pair_in_detector() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.EIGHT, Suit.HEARTS], [Rank.WILD, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(PairCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.EIGHT))


func test_straight_detector_two_card_with_wild() -> void:
	var cards := _cards([[Rank.EIGHT, Suit.HEARTS], [Rank.WILD, Suit.SPADES]])
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		return CardEnums.rank_weight(a.rank) < CardEnums.rank_weight(b.rank)
	)
	var combination: Variant = StraightDetector.detect(cards)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.EIGHT))


func test_straight_detector_ace_plus_wild_is_ka() -> void:
	var cards := _cards([[Rank.ACE, Suit.HEARTS], [Rank.WILD, Suit.SPADES]])
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		return CardEnums.rank_weight(a.rank) < CardEnums.rank_weight(b.rank)
	)
	var combination: Variant = StraightDetector.detect(cards)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.KING))


func test_two_straight_circular() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.KING, Suit.HEARTS], [Rank.ACE, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.KING))

	combination = CombinationDetector.calculate_combination(
		_cards([[Rank.ACE, Suit.HEARTS], [Rank.TWO, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(1)

	combination = CombinationDetector.calculate_combination(
		_cards([[Rank.TWO, Suit.HEARTS], [Rank.THREE, Suit.SPADES]])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(2)


func test_two_card_invalid_non_consecutive() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.SIX, Suit.HEARTS], [Rank.EIGHT, Suit.SPADES]])
	)
	assert_that(combination).is_null()


func test_incomplete_rocket_joker_pairs() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.SMALL_JOKER, Suit.HEARTS], [Rank.SMALL_JOKER, Suit.SPADES]])
	)
	assert_that(combination).is_null()

	combination = CombinationDetector.calculate_combination(
		_cards([[Rank.BIG_JOKER, Suit.HEARTS], [Rank.BIG_JOKER, Suit.SPADES]])
	)
	assert_that(combination).is_null()


func test_incomplete_two_card_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([[Rank.ACE, Suit.HEARTS], [Rank.FOUR, Suit.SPADES]])
	)
	assert_that(combination).is_null()

	combination = CombinationDetector.calculate_combination(
		_cards([[Rank.KING, Suit.HEARTS], [Rank.FOUR, Suit.SPADES]])
	)
	assert_that(combination).is_null()


func test_bomb_three_of_a_kind() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.KING, Suit.HEARTS],
			[Rank.KING, Suit.DIAMONDS],
			[Rank.KING, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(BombCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.KING))
	assert_that((combination as BombCombination).length).is_equal(3)


func test_wild_bomb() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.FIVE, Suit.HEARTS],
			[Rank.FIVE, Suit.SPADES],
			[Rank.WILD, Suit.DIAMONDS],
			[Rank.WILD, Suit.DIAMONDS],
			[Rank.WILD, Suit.DIAMONDS],
		])
	)
	assert_that(combination).is_instanceof(BombCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.FIVE))
	assert_that((combination as BombCombination).length).is_equal(5)


func test_normal_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.KING, Suit.SPADES],
			[Rank.ACE, Suit.SPADES],
			[Rank.TWO, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.KING))


func test_low_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.ACE, Suit.SPADES],
			[Rank.TWO, Suit.SPADES],
			[Rank.THREE, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(1)


func test_high_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.THREE, Suit.SPADES],
			[Rank.TWO, Suit.SPADES],
			[Rank.FOUR, Suit.SPADES],
			[Rank.KING, Suit.SPADES],
			[Rank.ACE, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(13)


func test_low_straight_with_wilds() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.WILD, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.SEVEN, Suit.SPADES],
			[Rank.SIX, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.SIX))


func test_high_straight_with_wilds() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.ACE, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.WILD, Suit.SPADES],
			[Rank.THREE, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(11)


func test_jokers_in_multi_card_combinations_are_invalid() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.SIX, Suit.HEARTS],
			[Rank.SEVEN, Suit.SPADES],
			[Rank.SMALL_JOKER, Suit.JOKERS],
		])
	)
	assert_that(combination).is_null()

	combination = CombinationDetector.calculate_combination(
		_cards([
			[Rank.SEVEN, Suit.HEARTS],
			[Rank.SEVEN, Suit.SPADES],
			[Rank.SEVEN, Suit.CLUBS],
			[Rank.BIG_JOKER, Suit.JOKERS],
		])
	)
	assert_that(combination).is_null()


func test_incomplete_bomb() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.SEVEN, Suit.HEARTS],
			[Rank.SEVEN, Suit.SPADES],
			[Rank.SEVEN, Suit.CLUBS],
			[Rank.SEVEN, Suit.DIAMONDS],
			[Rank.NINE, Suit.DIAMONDS],
		])
	)
	assert_that(combination).is_null()


func test_incomplete_high_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.THREE, Suit.SPADES],
			[Rank.TWO, Suit.SPADES],
			[Rank.JACK, Suit.SPADES],
			[Rank.KING, Suit.SPADES],
			[Rank.ACE, Suit.SPADES],
		])
	)
	assert_that(combination).is_null()


func test_five_wild_seven_wild_straight() -> void:
	var combination: Variant = CombinationDetector.calculate_combination(
		_cards([
			[Rank.FIVE, Suit.HEARTS],
			[Rank.WILD, Suit.SPADES],
			[Rank.SEVEN, Suit.HEARTS],
			[Rank.WILD, Suit.SPADES],
		])
	)
	assert_that(combination).is_instanceof(StraightCombination)
	assert_that(combination.power).is_equal(CardEnums.rank_weight(Rank.FIVE))


func test_empty_list() -> void:
	var combination: Variant = CombinationDetector.calculate_combination([])
	assert_that(combination).is_null()
