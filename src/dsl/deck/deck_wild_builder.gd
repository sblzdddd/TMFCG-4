class_name DeckWildBuilder
extends RefCounted
## Build a match deck from DeckData with one elevatable rank raised to WILD.


static func build(deck_data: DeckData, p_wild_rank: CardEnums.Rank = CardEnums.Rank.NONE) -> Deck:
	if deck_data == null:
		return Deck.empty()
	var present: Dictionary = {}
	for source_data in deck_data.cards:
		if source_data == null:
			continue
		present[source_data.rank] = true
	if present.is_empty():
		return Deck.empty()

	var wild_rank := p_wild_rank
	if wild_rank == CardEnums.Rank.NONE:
		wild_rank = _pick_wild_rank(present)
	var cards: Array[Card] = []
	for source_data in deck_data.cards:
		if source_data == null:
			continue
		var duplicated_data := source_data.duplicate(true) as CardData
		if duplicated_data == null:
			continue
		# Elevate the copy before constructing the runtime Card. This guarantees
		# no runtime card retains the selected printed rank.
		if duplicated_data.rank == wild_rank:
			duplicated_data.rank = CardEnums.Rank.WILD
		cards.append(Card.from_data(duplicated_data))
	for card in cards:
		card.restrict_visibility_to([])
	cards.shuffle()
	_move_one_wild_to_end(cards)
	_reveal_bottom_card(cards)
	return Deck.new(cards, wild_rank)


static func _pick_wild_rank(present: Dictionary) -> CardEnums.Rank:
	var candidates: Array[CardEnums.Rank] = []
	for rank in CardEnums.elevatable_ranks():
		if present.has(rank):
			candidates.append(rank)
	if candidates.is_empty():
		var all_ranks := CardEnums.elevatable_ranks()
		return all_ranks[randi() % all_ranks.size()]
	return candidates[randi() % candidates.size()]


static func _move_one_wild_to_end(cards: Array[Card]) -> void:
	var wilds: Array[Card] = []
	for card in cards:
		if card != null and card.rank == CardEnums.Rank.WILD:
			wilds.append(card)
	if wilds.is_empty():
		return
	var pick := wilds[randi() % wilds.size()]
	cards.erase(pick)
	cards.append(pick)


static func _reveal_bottom_card(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	var bottom := cards[cards.size() - 1]
	if bottom != null:
		bottom.make_public()
