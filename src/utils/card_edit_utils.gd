extends RefCounted
class_name CardEditUtils

const Suit := CardEnums.Suit
const Rank := CardEnums.Rank

const SUIT_LABELS := {
	Suit.CLUBS: "梅花",
	Suit.DIAMONDS: "方片",
	Suit.HEARTS: "红心",
	Suit.SPADES: "黑桃",
	Suit.JOKERS: "大/小王",
}


static func populate_suit_option(
	button: OptionButton,
	club_icon: Texture2D,
	diamond_icon: Texture2D,
	heart_icon: Texture2D,
	spade_icon: Texture2D
) -> void:
	button.clear()
	var icons := {
		Suit.CLUBS: club_icon,
		Suit.DIAMONDS: diamond_icon,
		Suit.HEARTS: heart_icon,
		Suit.SPADES: spade_icon,
	}
	for suit in [Suit.CLUBS, Suit.DIAMONDS, Suit.HEARTS, Suit.SPADES, Suit.JOKERS]:
		var icon: Texture2D = icons.get(suit)
		if icon:
			button.add_icon_item(icon, SUIT_LABELS[suit], int(suit))
		else:
			button.add_item(SUIT_LABELS[suit], int(suit))


static func populate_value_option(button: OptionButton) -> void:
	button.clear()
	for rank in CardUtils.NORMAL_RANKS:
		button.add_item(CardUtils.rank_display(rank), int(rank))
	for rank in CardUtils.JOKER_RANKS:
		button.add_item(CardUtils.rank_display(rank), int(rank))


static func update_value_availability(button: OptionButton, suit: Suit, current_rank: Rank) -> Rank:
	var valid := CardUtils.valid_ranks_for_suit(suit)
	for i in range(button.item_count):
		var rank := button.get_item_id(i) as Rank
		button.set_item_disabled(i, not (rank in valid))

	var resolved_rank := current_rank
	if not CardUtils.is_rank_valid_for_suit(suit, resolved_rank):
		resolved_rank = valid[0]

	select_rank(button, resolved_rank)
	return resolved_rank


static func select_suit(button: OptionButton, suit: Suit) -> void:
	for i in range(button.item_count):
		if button.get_item_id(i) == int(suit):
			button.select(i)
			return


static func select_rank(button: OptionButton, rank: Rank) -> void:
	for i in range(button.item_count):
		if button.get_item_id(i) == int(rank):
			button.select(i)
			return


static func get_selected_suit(button: OptionButton) -> Suit:
	return button.get_selected_id() as Suit


static func get_selected_rank(button: OptionButton) -> Rank:
	return button.get_selected_id() as Rank
