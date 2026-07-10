class_name CardEnums

enum Suit {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES,
	JOKERS,
}

enum Rank {
	NONE,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	ACE = 21,
	TWO = 22,
	WILD = 25,
	SMALL_JOKER = 30,
	BIG_JOKER = 40,
}

enum Type {
	NORMAL,
	SKILL
}

const LEGACY_WILD_VALUE := 23


static func rank_weight(rank: Rank) -> int:
	return int(rank)


static func rank_display_name(rank: Rank) -> String:
	match rank:
		Rank.THREE: return "3"
		Rank.FOUR: return "4"
		Rank.FIVE: return "5"
		Rank.SIX: return "6"
		Rank.SEVEN: return "7"
		Rank.EIGHT: return "8"
		Rank.NINE: return "9"
		Rank.TEN: return "10"
		Rank.JACK: return "J"
		Rank.QUEEN: return "Q"
		Rank.KING: return "K"
		Rank.ACE: return "A"
		Rank.TWO: return "2"
		Rank.WILD: return "W"
		Rank.SMALL_JOKER: return "SJ"
		Rank.BIG_JOKER: return "BJ"
		_: return "-"


static func suit_display_name(suit: Suit) -> String:
	match suit:
		Suit.SPADES: return "♠️"
		Suit.HEARTS: return "♥️"
		Suit.CLUBS: return "♣️"
		Suit.DIAMONDS: return "♦️"
		Suit.JOKERS: return "🃏"
		_: return ""


static func rank_from_name(name: String) -> Rank:
	var key := name.to_upper()
	for rank in Rank.values():
		if rank == Rank.NONE:
			continue
		if Rank.find_key(rank) == key:
			return rank
	return Rank.NONE


static func suit_from_name(name: String) -> Suit:
	var key := name.to_upper()
	for suit in Suit.values():
		if Suit.find_key(suit) == key:
			return suit
	return Suit.CLUBS


static func migrate_legacy_rank(stored_value: int) -> Rank:
	if stored_value == LEGACY_WILD_VALUE:
		return Rank.WILD
	for rank in Rank.values():
		if int(rank) == stored_value:
			return rank
	return Rank.NONE


static func to_normal(rank: Rank) -> int:
	match rank:
		Rank.ACE: return 14
		Rank.TWO: return 15
		_: return rank_weight(rank)


static func to_low(rank: Rank) -> int:
	match rank:
		Rank.ACE: return 1
		Rank.TWO: return 2
		_: return rank_weight(rank)


static func to_wrap_high(rank: Rank) -> int:
	match rank:
		Rank.JACK, Rank.QUEEN, Rank.KING: return rank_weight(rank)
		Rank.ACE: return 14
		Rank.TWO: return 15
		_: return rank_weight(rank) + 13


static func elevatable_ranks() -> Array[Rank]:
	var ranks: Array[Rank] = []
	for rank in Rank.values():
		if rank != Rank.NONE and rank_weight(rank) < rank_weight(Rank.TWO):
			ranks.append(rank)
	return ranks


static func normal_ranks() -> Array[Rank]:
	var ranks: Array[Rank] = []
	for rank in Rank.values():
		if rank != Rank.NONE and rank_weight(rank) < rank_weight(Rank.WILD):
			ranks.append(rank)
	return ranks


static func normal_suits() -> Array[Suit]:
	var suits: Array[Suit] = []
	for suit in Suit.values():
		if suit != Suit.JOKERS:
			suits.append(suit)
	return suits
