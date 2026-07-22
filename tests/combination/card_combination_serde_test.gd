# GdUnit TestSuite
class_name CardCombinationSerdeTestSuite
extends GdUnitTestSuite


func test_round_trip_bomb() -> void:
	var bomb := BombCombination.new([], CardEnums.rank_weight(CardEnums.Rank.SEVEN), 4)
	var restored := CardCombinationSerde.from_dict(CardCombinationSerde.to_dict(bomb))
	assert_that(restored).is_instanceof(BombCombination)
	assert_that(restored.power).is_equal(bomb.power)
	assert_that((restored as BombCombination).length).is_equal(4)


func test_empty_dict_is_null() -> void:
	assert_that(CardCombinationSerde.from_dict({})).is_null()
