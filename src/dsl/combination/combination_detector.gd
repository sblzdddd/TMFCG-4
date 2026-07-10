class_name CombinationDetector
extends RefCounted


static func calculate_combination(cards: Array[Card]):
	if cards.is_empty():
		return null

	if cards.size() == 1:
		return SingleCombination.new(cards, CardEnums.rank_weight(cards[0].rank))

	var sorted_cards := cards.duplicate()
	sorted_cards.sort_custom(func(a: Card, b: Card) -> bool:
		return CardEnums.rank_weight(a.rank) < CardEnums.rank_weight(b.rank)
	)

	match sorted_cards.size():
		2:
			for detector in [BombDetector.detect, PairDetector.detect, StraightDetector.detect]:
				var result: CardCombination = detector.call(sorted_cards)
				if result != null:
					return result
			return null
		3, 4, 5, 6:
			for detector in [BombDetector.detect, StraightDetector.detect]:
				var result: CardCombination = detector.call(sorted_cards)
				if result != null:
					return result
			return null
		_:
			return null
