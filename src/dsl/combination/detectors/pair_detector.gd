class_name PairDetector
extends RefCounted


static func detect(cards: Array[Card]):
	if cards.size() != 2:
		return null

	var c1 := cards[0]
	var c2 := cards[1]

	if c1.rank > CardEnums.Rank.SMALL_JOKER or c2.rank >= CardEnums.Rank.SMALL_JOKER:
		return null

	if c1.rank == c2.rank or c2.rank == CardEnums.Rank.WILD:
		return PairCombination.new(cards, CardEnums.rank_weight(c1.rank))

	return null
