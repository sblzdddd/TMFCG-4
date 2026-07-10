class_name Deck
extends RefCounted

var _cards: Array[Card] = []
var wild_rank: CardEnums.Rank


func _init(cards: Array[Card] = [], p_wild_rank: CardEnums.Rank = CardEnums.Rank.THREE) -> void:
	_cards = cards.duplicate()
	wild_rank = p_wild_rank


func get_size() -> int:
	return _cards.size()


func draw(count: int = 1) -> Array:
	var selected := _cards.slice(0, count) as Array[Card]
	var remaining := _cards.slice(count, _cards.size()) as Array[Card]
	return [selected, Deck.new(remaining, wild_rank)]


func get_card(index: int):
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index]


func get_cards(range_start: int, range_end: int):
	if range_start < 0 or range_end > _cards.size() - 1 or range_start > range_end:
		return null
	return _cards.slice(range_start, range_end + 1) as Array[Card]


func insert_card(card: Card, index: int) -> Deck:
	var updated := _cards.duplicate()
	updated.insert(index, card)
	return Deck.new(updated, wild_rank)


static func empty(p_wild_rank: CardEnums.Rank = _random_elevatable_rank()) -> Deck:
	return Deck.new([], p_wild_rank)


static func create_new(p_wild_rank: CardEnums.Rank = _random_elevatable_rank()) -> Deck:
	var all_cards: Array[Card] = []
	for suit in CardEnums.normal_suits():
		for rank in CardEnums.normal_ranks():
			if rank == p_wild_rank:
				all_cards.append(Card.new(CardEnums.Rank.WILD, suit))
			else:
				all_cards.append(Card.new(rank, suit))

	all_cards.append(Card.new(CardEnums.Rank.BIG_JOKER, CardEnums.Suit.JOKERS))
	all_cards.append(Card.new(CardEnums.Rank.SMALL_JOKER, CardEnums.Suit.JOKERS))

	var shuffled := all_cards.duplicate()
	shuffled.shuffle()

	var wild_cards: Array[Card] = []
	for card in shuffled:
		if card.rank == CardEnums.Rank.WILD:
			wild_cards.append(card)

	if not wild_cards.is_empty():
		var wild_card := wild_cards[randi() % wild_cards.size()]
		all_cards.erase(wild_card)
		all_cards.append(wild_card)

	return Deck.new(shuffled, p_wild_rank)


static func _random_elevatable_rank() -> CardEnums.Rank:
	var ranks := CardEnums.elevatable_ranks()
	return ranks[randi() % ranks.size()]
