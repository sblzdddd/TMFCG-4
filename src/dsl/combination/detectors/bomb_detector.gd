class_name BombDetector
extends RefCounted


static func detect(cards: Array[Card]):
	if cards.size() < 2:
		return null

	if cards.size() == 2:
		var c1 := cards[0]
		var c2 := cards[1]
		if c1.rank == CardEnums.Rank.SMALL_JOKER and c2.rank == CardEnums.Rank.BIG_JOKER:
			return BombCombination.new(cards, CardEnums.rank_weight(c1.rank), 3)
		return null

	if cards.size() > 6:
		return null

	for card in cards:
		if card.rank >= CardEnums.Rank.SMALL_JOKER:
			return null

	var base_rank := cards[0].rank
	for card in cards:
		if card.rank != base_rank and card.rank != CardEnums.Rank.WILD:
			return null

	return BombCombination.new(cards, CardEnums.rank_weight(base_rank), cards.size())
