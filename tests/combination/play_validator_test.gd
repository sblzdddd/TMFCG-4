# GdUnit TestSuite
class_name PlayValidatorTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func _cards(specs: Array) -> Array[Card]:
	return TestFixtures.make_cards(specs)


func test_lead_accepts_any_legal_combo() -> void:
	var result := PlayValidator.evaluate(_cards([[Rank.THREE, Suit.HEARTS]]), null)
	assert_that(result.get("ok")).is_true()
	assert_that(result.get("combo")).is_instanceof(SingleCombination)


func test_illegal_shape_rejected() -> void:
	var result := PlayValidator.evaluate(
		_cards([[Rank.THREE, Suit.HEARTS], [Rank.FIVE, Suit.SPADES]]),
		null,
	)
	assert_that(result.get("ok")).is_false()


func test_must_beat_current_trick() -> void:
	var current := SingleCombination.new(
		_cards([[Rank.FIVE, Suit.HEARTS]]),
		CardEnums.rank_weight(Rank.FIVE),
	)
	var lose := PlayValidator.evaluate(_cards([[Rank.THREE, Suit.SPADES]]), current)
	assert_that(lose.get("ok")).is_false()
	var win := PlayValidator.evaluate(_cards([[Rank.KING, Suit.SPADES]]), current)
	assert_that(win.get("ok")).is_true()


func test_wild_pair_can_beat_two_straight_as_straight() -> void:
	var current := StraightCombination.new(
		_cards([[Rank.SEVEN, Suit.HEARTS], [Rank.EIGHT, Suit.SPADES]]),
		CardEnums.rank_weight(Rank.SEVEN),
	)
	var eight_wild := PlayValidator.evaluate(
		_cards([[Rank.EIGHT, Suit.HEARTS], [Rank.WILD, Suit.SPADES]]),
		current,
	)
	assert_that(eight_wild.get("ok")).is_true()
	assert_that(eight_wild.get("combo")).is_instanceof(StraightCombination)

	var nine_wild := PlayValidator.evaluate(
		_cards([[Rank.NINE, Suit.HEARTS], [Rank.WILD, Suit.SPADES]]),
		current,
	)
	assert_that(nine_wild.get("ok")).is_true()

	var two_wild := PlayValidator.evaluate(
		_cards([[Rank.WILD, Suit.HEARTS], [Rank.WILD, Suit.SPADES]]),
		current,
	)
	assert_that(two_wild.get("ok")).is_true()
	assert_that(two_wild.get("combo")).is_instanceof(StraightCombination)


func test_ace_plus_wild_beats_two_straight_as_ka() -> void:
	# Ace+wild prefers pair AA in the detector; as a 2-straight it must be K-A, not A-2.
	var current := StraightCombination.new(
		_cards([[Rank.SEVEN, Suit.HEARTS], [Rank.EIGHT, Suit.SPADES]]),
		CardEnums.rank_weight(Rank.SEVEN),
	)
	var ace_wild := PlayValidator.evaluate(
		_cards([[Rank.ACE, Suit.HEARTS], [Rank.WILD, Suit.SPADES]]),
		current,
	)
	assert_that(ace_wild.get("ok")).is_true()
	assert_that(ace_wild.get("combo")).is_instanceof(StraightCombination)
	assert_that((ace_wild.get("combo") as StraightCombination).power).is_equal(
		CardEnums.rank_weight(Rank.KING)
	)


func test_rank_plus_wild_still_leads_as_pair() -> void:
	var result := PlayValidator.evaluate(
		_cards([[Rank.EIGHT, Suit.HEARTS], [Rank.WILD, Suit.SPADES]]),
		null,
	)
	assert_that(result.get("ok")).is_true()
	assert_that(result.get("combo")).is_instanceof(PairCombination)


func test_two_straight_cannot_beat_three_straight() -> void:
	var current: CardCombination = CombinationDetector.calculate_combination(
		_cards([
			[Rank.THREE, Suit.HEARTS],
			[Rank.FOUR, Suit.SPADES],
			[Rank.FIVE, Suit.CLUBS],
		])
	)
	var result := PlayValidator.evaluate(
		_cards([[Rank.JACK, Suit.HEARTS], [Rank.QUEEN, Suit.SPADES]]),
		current,
	)
	assert_that(result.get("ok")).is_false()
