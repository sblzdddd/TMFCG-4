class_name PlayValidator
extends RefCounted
## Legal play shape + beat check against the current trick combo.


static func evaluate(cards: Array[Card], current_trick: CardCombination) -> Dictionary:
	var combo: CardCombination = CombinationDetector.calculate_combination(cards)
	if _beats(combo, current_trick):
		return {"ok": true, "combo": combo}
	# Rank+wild / WW is detected as a pair first; also try as 2-straight when needed.
	var alt := _alternate_two_card_straight(cards)
	if _beats(alt, current_trick):
		return {"ok": true, "combo": alt}
	return {"ok": false, "combo": combo}


static func _beats(combo: CardCombination, current_trick: CardCombination) -> bool:
	if combo == null:
		return false
	if current_trick == null:
		return true
	return combo.compare_to(current_trick) > 0


static func _alternate_two_card_straight(cards: Array[Card]) -> CardCombination:
	if cards.size() != 2:
		return null
	var has_wild := false
	for card in cards:
		if card.rank == CardEnums.Rank.WILD:
			has_wild = true
			break
	if not has_wild:
		return null
	var sorted_cards := cards.duplicate()
	sorted_cards.sort_custom(func(a: Card, b: Card) -> bool:
		return CardEnums.rank_weight(a.rank) < CardEnums.rank_weight(b.rank)
	)
	return StraightDetector.detect(sorted_cards)
