class_name Deck
extends CardHolder

const HOLDER_ID := "deck"

var wild_rank: CardEnums.Rank


func _init(
	cards: Array[Card] = [],
	p_wild_rank: CardEnums.Rank = CardEnums.Rank.THREE,
) -> void:
	super._init(Kind.DECK, HOLDER_ID, cards)
	wild_rank = p_wild_rank


func draw(count: int = 1) -> Array[Card]:
	if count <= 0 or _cards.is_empty():
		return []
	var n := mini(count, _cards.size())
	var selected: Array[Card] = []
	for i in n:
		selected.append(_cards[i])
	remove_cards(selected)
	return selected


func to_dict() -> Dictionary:
	var dict := super.to_dict()
	dict["wildRank"] = CardEnums.Rank.find_key(wild_rank)
	return dict


static func from_dict(dict: Dictionary) -> Deck:
	var deck := Deck.new(
		CardHolder.cards_from_dict(dict),
		CardEnums.rank_from_name(str(dict.get("wildRank", "THREE"))),
	)
	return deck


static func empty(p_wild_rank: CardEnums.Rank = _random_elevatable_rank()) -> Deck:
	return Deck.new([], p_wild_rank)


## Creates runtime cards without retaining or mutating the editor resources.
## This is intended to be called once by the authoritative host.
static func from_deck_data(deck_data: DeckData) -> Deck:
	if deck_data == null:
		return Deck.empty()
	var cards: Array[Card] = []
	for source_data in deck_data.cards:
		if source_data == null:
			continue
		var duplicated_data := source_data.duplicate(true) as CardData
		var card := Card.from_data(duplicated_data)
		card.restrict_visibility_to([])
		cards.append(card)
	cards.shuffle()
	return Deck.new(cards)


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
	for card in all_cards:
		card.restrict_visibility_to([])

	var shuffled := all_cards.duplicate()
	shuffled.shuffle()

	var wild_cards: Array[Card] = []
	for card in shuffled:
		if card.rank == CardEnums.Rank.WILD:
			wild_cards.append(card)

	if not wild_cards.is_empty():
		var wild_card := wild_cards[randi() % wild_cards.size()]
		shuffled.erase(wild_card)
		shuffled.append(wild_card)

	return Deck.new(shuffled, p_wild_rank)


static func _random_elevatable_rank() -> CardEnums.Rank:
	var ranks := CardEnums.elevatable_ranks()
	return ranks[randi() % ranks.size()]
