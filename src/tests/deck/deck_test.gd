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
	var draw_result := deck.draw()
	var new_deck: Deck = draw_result[1]
	assert_that(new_deck.get_size()).is_equal(initial_size - 1)


func test_draw_returns_cards() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	var draw_result := deck.draw(5)
	var cards: Array = draw_result[0]
	assert_that(cards.size()).is_equal(5)


func test_insert_card_at_desired_position() -> void:
	var deck := Deck.create_new(Rank.FIVE)
	var card := Card.new(Rank.WILD, Suit.DIAMONDS)
	var new_deck := deck.insert_card(card, 4)
	var retrieved: Variant = new_deck.get_card(4)
	assert_that(retrieved).is_not_null()
	assert_that(retrieved.rank).is_equal(Rank.WILD)
	assert_that(retrieved.suit).is_equal(Suit.DIAMONDS)


func test_get_cards_checks_boundary() -> void:
	var deck := Deck.create_new(Rank.FIVE)

	var cards: Variant = deck.get_cards(0, 1)
	assert_that(cards).is_not_null()
	assert_that(cards.size()).is_equal(2)

	assert_that(deck.get_cards(-1, 1)).is_null()
	assert_that(deck.get_cards(0, deck.get_size())).is_null()
