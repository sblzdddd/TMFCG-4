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
	WILD = 23,
	SMALL_JOKER = 30,
	LARGE_JOKER = 40,
}

enum Type {
	NORMAL,
	SKILL
}

static func to_normal(rank: Rank) -> int:
	match rank:
		Rank.ACE: return 14
		Rank.TWO: return 15
		_: return int(rank)

static func to_low(rank: Rank) -> int:
	match rank:
		Rank.ACE: return 1
		Rank.TWO: return 2
		_: return int(rank)

static func to_wrap_high(rank: Rank) -> int:
	match rank:
		Rank.JACK, Rank.QUEEN, Rank.KING: return 10
		Rank.ACE: return 14
		Rank.TWO: return 15
		_: return int(rank)