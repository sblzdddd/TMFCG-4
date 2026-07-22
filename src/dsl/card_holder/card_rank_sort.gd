class_name CardRankSort
extends RefCounted
## Sort cards by rank weight, then suit.


static func sort_cards(
	cards: Array[Card],
	wild_rank: CardEnums.Rank = CardEnums.Rank.NONE,
) -> void:
	cards.sort_custom(
		func(a: Card, b: Card) -> bool: return _less(a, b, wild_rank)
	)


static func _less(
	a: Card,
	b: Card,
	wild_rank: CardEnums.Rank = CardEnums.Rank.NONE,
) -> bool:
	var aw := _display_weight(a, wild_rank)
	var bw := _display_weight(b, wild_rank)
	if aw != bw:
		return aw < bw
	if a.suit != b.suit:
		return int(a.suit) < int(b.suit)
	# Godot's custom sort is not stable. A final authoritative key keeps cards
	# with equal rank/suit in the same order on the server and every client.
	return a.instance_id.value < b.instance_id.value


static func _display_weight(card: Card, wild_rank: CardEnums.Rank) -> int:
	if card.rank == CardEnums.Rank.WILD and wild_rank != CardEnums.Rank.NONE:
		return CardEnums.rank_weight(wild_rank)
	return CardEnums.rank_weight(card.rank)
