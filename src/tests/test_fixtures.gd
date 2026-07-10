class_name TestFixtures
extends RefCounted

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


static func make_card(rank: Rank, suit: Suit) -> Card:
	return Card.new(rank, suit)


static func make_cards(card_specs: Array) -> Array[Card]:
	var cards: Array[Card] = []
	for spec in card_specs:
		cards.append(make_card(spec[0], spec[1]))
	return cards
