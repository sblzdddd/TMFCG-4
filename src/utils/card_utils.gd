extends RefCounted
class_name CardUtils

const Suit := CardEnums.Suit
const Rank := CardEnums.Rank

const ICON_CLUB := preload("res://assets/textures/icons/club.svg")
const ICON_DIAMOND := preload("res://assets/textures/icons/diamond.svg")
const ICON_HEART := preload("res://assets/textures/icons/heart.svg")
const ICON_SPADE := preload("res://assets/textures/icons/spade.svg")

const NORMAL_RANKS: Array[Rank] = [
	Rank.ACE,
	Rank.TWO,
	Rank.THREE,
	Rank.FOUR,
	Rank.FIVE,
	Rank.SIX,
	Rank.SEVEN,
	Rank.EIGHT,
	Rank.NINE,
	Rank.TEN,
	Rank.JACK,
	Rank.QUEEN,
	Rank.KING,
]

const JOKER_RANKS: Array[Rank] = [
	Rank.SMALL_JOKER,
	Rank.BIG_JOKER,
]

const NORMAL_SUITS: Array[Suit] = [
	Suit.CLUBS,
	Suit.DIAMONDS,
	Suit.HEARTS,
	Suit.SPADES,
]


static func create_default_deck_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for suit in NORMAL_SUITS:
		for rank in NORMAL_RANKS:
			cards.append(create_card(suit, rank))
	cards.append(create_card(Suit.JOKERS, Rank.SMALL_JOKER))
	cards.append(create_card(Suit.JOKERS, Rank.BIG_JOKER))
	return cards


static func create_card(suit: Suit, rank: Rank) -> CardData:
	var card := CardData.new()
	card.suit = suit
	card.rank = rank
	card.cardId = "card-%d-%d" % [int(suit), int(rank)]
	return card


static func rank_display(rank: Rank) -> String:
	match rank:
		Rank.SMALL_JOKER: return "小王"
		Rank.BIG_JOKER: return "大王"
		_: return CardEnums.rank_display_name(rank)


static func suit_icon(suit: Suit) -> Texture2D:
	match suit:
		Suit.CLUBS: return ICON_CLUB
		Suit.DIAMONDS: return ICON_DIAMOND
		Suit.HEARTS: return ICON_HEART
		Suit.SPADES: return ICON_SPADE
		_: return null


static func rank_to_shader_value(rank: Rank) -> int:
	match rank:
		Rank.ACE: return 1
		Rank.TWO: return 2
		Rank.THREE: return 3
		Rank.FOUR: return 4
		Rank.FIVE: return 5
		Rank.SIX: return 6
		Rank.SEVEN: return 7
		Rank.EIGHT: return 8
		Rank.NINE: return 9
		Rank.TEN: return 10
		Rank.JACK: return 11
		Rank.QUEEN: return 12
		Rank.KING: return 13
		_: return 0


static func suit_to_shader_value(suit: Suit) -> int:
	match suit:
		Suit.CLUBS: return 0
		Suit.DIAMONDS: return 1
		Suit.HEARTS: return 2
		Suit.SPADES: return 3
		_: return 0


static func is_joker_suit(suit: Suit) -> bool:
	return suit == Suit.JOKERS


static func valid_ranks_for_suit(suit: Suit) -> Array[Rank]:
	if is_joker_suit(suit):
		return JOKER_RANKS.duplicate()
	return NORMAL_RANKS.duplicate()


static func is_rank_valid_for_suit(suit: Suit, rank: Rank) -> bool:
	return rank in valid_ranks_for_suit(suit)


static func card_tree_label(card: CardData) -> String:
	var rank_text := rank_display(card.rank)
	if card.visual == null or card.visual.character == null:
		return rank_text
	var character_name := CharacterUtils.get_english_display_name(card.visual.character)
	if character_name.is_empty():
		return rank_text
	return "%s (%s)" % [rank_text, character_name]
