class_name StraightDetector
extends RefCounted


static func detect(cards: Array[Card]):
	for card in cards:
		if card.rank >= CardEnums.Rank.SMALL_JOKER:
			return null

	if cards.size() == 2:
		return _detect_two_cards(cards)
	return _detect_multiple_cards(cards)


static func _detect_two_cards(cards: Array[Card]):
	var c1: Card = cards[0]
	var c2: Card = cards[1]
	# Sorted by rank weight: wilds (25) always last.
	if c1.rank == CardEnums.Rank.WILD and c2.rank == CardEnums.Rank.WILD:
		# Strongest natural 2-straight is K-A.
		return StraightCombination.new(cards, CardEnums.rank_weight(CardEnums.Rank.KING))
	if c2.rank == CardEnums.Rank.WILD and c1.rank != CardEnums.Rank.WILD:
		var power := _two_card_start_power(c1.rank)
		if power < 0:
			return null
		return StraightCombination.new(cards, power)
	if not _is_consecutive(c1, c2):
		return null

	var straight_power: int
	if c1.rank == CardEnums.Rank.ACE:
		straight_power = 1
	elif c1.rank == CardEnums.Rank.THREE and c2.rank == CardEnums.Rank.TWO:
		straight_power = 2
	else:
		straight_power = CardEnums.rank_weight(c1.rank)

	return StraightCombination.new(cards, straight_power)


## Best 2-straight power for [rank]+wild. -1 if impossible.
## Prefer the stronger adjacency: Ace+wild is K-A (not A-2); other ranks start at [rank].
static func _two_card_start_power(rank: CardEnums.Rank) -> int:
	match rank:
		CardEnums.Rank.TWO:
			return -1
		CardEnums.Rank.ACE:
			# Wild fills as King → K-A (strongest 2-straight). A-2 would be power 1 and never useful.
			return CardEnums.rank_weight(CardEnums.Rank.KING)
		_:
			return CardEnums.rank_weight(rank)


static func _is_consecutive(c1: Card, c2: Card) -> bool:
	var r1 := c1.rank
	var r2 := c2.rank
	var w1 := CardEnums.rank_weight(r1)
	var w2 := CardEnums.rank_weight(r2)
	return (w1 + 1 == w2) \
		or (r1 == CardEnums.Rank.KING and r2 == CardEnums.Rank.ACE) \
		or (r1 == CardEnums.Rank.ACE and r2 == CardEnums.Rank.TWO) \
		or (r1 == CardEnums.Rank.THREE and r2 == CardEnums.Rank.TWO)


static func _detect_multiple_cards(cards: Array[Card]):
	for card in cards:
		if card.rank >= CardEnums.Rank.SMALL_JOKER:
			return null

	var straight_power: int = _calculate_straight_power(cards)
	if straight_power < 0:
		return null
	return StraightCombination.new(cards, straight_power)


static func _calculate_straight_power(cards: Array[Card]) -> int:
	var wild_count := 0
	for card in cards:
		if card.rank == CardEnums.Rank.WILD:
			wild_count += 1

	var non_wild: Array[Card] = []
	for card in cards:
		if card.rank != CardEnums.Rank.WILD:
			non_wild.append(card)

	var seen_ranks: Dictionary = {}
	for card in non_wild:
		if seen_ranks.has(card.rank):
			return -1
		seen_ranks[card.rank] = true

	var results: Array = []

	var normal_values: Array[int] = []
	for card in non_wild:
		normal_values.append(CardEnums.to_normal(card.rank))
	var normal_result = _try_sequence(normal_values, wild_count)
	if normal_result != null:
		results.append(normal_result)

	var low_values: Array[int] = []
	for card in non_wild:
		low_values.append(CardEnums.to_low(card.rank))
	var low_result = _try_sequence(low_values, wild_count, true)
	if low_result != null:
		results.append(low_result)

	var wrap_values: Array[int] = []
	for card in non_wild:
		wrap_values.append(CardEnums.to_wrap_high(card.rank))
	var wrap_result = _try_sequence(wrap_values, wild_count, false, 3)
	if wrap_result != null and wrap_result[0] <= 13:
		results.append(wrap_result)

	if results.is_empty():
		return -1

	results.sort_custom(func(a: Array, b: Array) -> bool:
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[0] > b[0]
	)
	return results[0][0]


static func _try_sequence(
	values: Array[int],
	wild_count: int,
	extend_left: bool = false,
	min_start: int = -1,
):
	var sorted := values.duplicate()
	sorted.sort()
	var span: int = sorted[sorted.size() - 1] - sorted[0] + 1
	var needed_wilds: int = span - sorted.size()
	if needed_wilds > wild_count:
		return null

	var extra_wilds: int = wild_count - needed_wilds
	var length: int = span + extra_wilds
	if length < 3:
		return null

	var start: int
	if min_start >= 0:
		start = maxi(min_start, sorted[0] - extra_wilds)
	elif extend_left:
		start = sorted[0] - extra_wilds
		if start < 1:
			start += 13
	else:
		start = sorted[0]

	return [start, length]
