# GdUnit TestSuite
class_name DeckTestSuite
extends GdUnitTestSuite

const Rank := CardEnums.Rank
const Suit := CardEnums.Suit


func test_deck_creation_works_correctly() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	assert_that(deck.get_size()).is_equal(54)


func test_draw_reduces_deck_size() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	var initial_size := deck.get_size()
	deck.draw()
	assert_that(deck.get_size()).is_equal(initial_size - 1)


func test_draw_returns_cards() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	var cards := deck.draw(5)
	assert_that(cards.size()).is_equal(5)
	assert_that(deck.get_size()).is_equal(49)


func test_insert_card_at_desired_position() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	var card := Card.new(Rank.WILD, Suit.DIAMONDS)
	deck.insert_card(card, 4)
	var retrieved: Variant = deck.get_card(4)
	assert_that(retrieved).is_not_null()
	assert_that(retrieved.rank).is_equal(Rank.WILD)
	assert_that(retrieved.suit).is_equal(Suit.DIAMONDS)


func test_get_cards_checks_boundary() -> void:
	var deck := Deck.create_new(Rank.FIVE)

	var cards: Array[Card] = deck.get_cards(0, 1)
	assert_that(cards.size()).is_equal(2)

	assert_that(deck.get_cards(-1, 1).is_empty()).is_true()
	assert_that(deck.get_cards(0, deck.get_size()).is_empty()).is_true()


func test_deck_serialization_round_trip() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	var drawn := deck.draw(3)
	var restored := Deck.from_dict(deck.to_dict())
	assert_that(restored.get_size()).is_equal(deck.get_size())
	assert_that(restored.wild_rank).is_equal(Rank.FIVE)
	assert_that(drawn.size()).is_equal(3)


func test_from_deck_data_duplicates_cards_and_assigns_unique_instances() -> void:
	var first := CardData.new()
	first.cardId = "first"
	first.rank = Rank.THREE
	first.suit = Suit.HEARTS
	var second := CardData.new()
	second.cardId = "second"
	second.rank = Rank.ACE
	second.suit = Suit.SPADES
	var source := DeckData.new()
	source.cards = [first, second]

	var deck := Deck.from_deck_data(source)
	assert_that(deck.get_size()).is_equal(2)
	var instance_ids: Dictionary = {}
	for card in deck.get_all_cards():
		instance_ids[card.instance_id.value] = true
		if card.data.cardId == "first":
			card.data.cardId = "runtime-only"
	assert_that(instance_ids.size()).is_equal(2)
	assert_str(first.cardId).is_equal("first")
	assert_str(second.cardId).is_equal("second")
	assert_that(source.cards.size()).is_equal(2)
