# GdUnit TestSuite
class_name DeckWildBuilderTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func _profile_with_ranks(ranks: Array) -> DeckData:
	var data := DeckData.new()
	var cards: Array[CardData] = []
	for rank in ranks:
		for suit in [Suit.HEARTS, Suit.SPADES]:
			var cd := CardData.new()
			cd.rank = rank
			cd.suit = suit
			cd.cardId = "%s-%s" % [CardEnums.Rank.find_key(rank), CardEnums.Suit.find_key(suit)]
			cards.append(cd)
	data.cards = cards
	return data


func test_build_elevates_chosen_rank_and_sets_wild_rank() -> void:
	var deck := DeckWildBuilder.build(_profile_with_ranks([Rank.THREE, Rank.FIVE, Rank.ACE]), Rank.FIVE)
	assert_that(deck.wild_rank).is_equal(Rank.FIVE)
	var wild_count := 0
	var five_count := 0
	for card in deck.get_all_cards():
		if card.rank == Rank.WILD:
			wild_count += 1
		if card.rank == Rank.FIVE:
			five_count += 1
	assert_that(wild_count).is_equal(2)
	assert_that(five_count).is_equal(0)


func test_build_moves_one_wild_to_end() -> void:
	var deck := DeckWildBuilder.build(_profile_with_ranks([Rank.THREE, Rank.FOUR]), Rank.THREE)
	assert_that(deck.get_size()).is_greater(0)
	var last := deck.get_card(deck.get_size() - 1)
	assert_that(last).is_not_null()
	assert_that(last.rank).is_equal(Rank.WILD)


func test_build_reveals_bottom_wild_only() -> void:
	var deck := DeckWildBuilder.build(_profile_with_ranks([Rank.THREE, Rank.FOUR]), Rank.THREE)
	var last := deck.get_card(deck.get_size() - 1)
	assert_that(last).is_not_null()
	assert_that(last.rank).is_equal(Rank.WILD)
	assert_bool(last.is_public).is_true()
	var hidden_wilds := 0
	for i in deck.get_size() - 1:
		var card := deck.get_card(i)
		if card == null:
			continue
		assert_bool(card.is_public).is_false()
		if card.rank == Rank.WILD:
			hidden_wilds += 1
	assert_that(hidden_wilds).is_equal(1)


func test_build_picks_present_elevatable_rank_when_none_given() -> void:
	var deck := DeckWildBuilder.build(_profile_with_ranks([Rank.SEVEN, Rank.EIGHT]))
	var ok := deck.wild_rank == Rank.SEVEN or deck.wild_rank == Rank.EIGHT
	assert_that(ok).is_true()
