# GdUnit TestSuite
class_name CardTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_card_comparison_works_correctly() -> void:
	var three := Card.new(Rank.THREE, Suit.HEARTS)
	var four := Card.new(Rank.FOUR, Suit.HEARTS)

	assert_bool(four.is_greater_than(three)).is_true()
	assert_bool(three.is_greater_than(four)).is_false()


func test_card_comparison_ignores_suit() -> void:
	var three_hearts := Card.new(Rank.THREE, Suit.HEARTS)
	var three_spades := Card.new(Rank.THREE, Suit.SPADES)

	assert_bool(three_hearts.is_greater_than(three_spades)).is_false()
	assert_bool(three_spades.is_greater_than(three_hearts)).is_false()


func test_card_pretty_print() -> void:
	var three_hearts := Card.new(Rank.THREE, Suit.HEARTS)
	assert_str(str(three_hearts)).is_equal("♥️3")
