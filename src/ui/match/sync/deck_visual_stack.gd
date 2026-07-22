class_name DeckVisualStack
extends Node
## Capped deck stand-in stack. Shrinks from top only; not 1:1 with draws.

const DECK_VISUAL_MAX := 10

@onready var deck: CardArray = %Deck

var _capacity := 0
var _next_index := 0


func sync_size(deck_size: int) -> void:
	if deck_size > 0 and _capacity <= 0:
		_capacity = deck_size
	var target := _visual_target(deck_size)
	var current := deck.get_ordered_ids().size()
	while current < target:
		var stand_in := _make_stand_in(_next_index)
		_next_index += 1
		deck.add_card(stand_in, {}, 0.0, -1, false)
		current += 1
	while current > target:
		var ids := deck.get_ordered_ids()
		await deck.remove_card(ids[ids.size() - 1], true, 0.0)
		current -= 1


func draw_pose() -> Dictionary:
	var ids := deck.get_ordered_ids()
	if ids.is_empty():
		return CardPose.origin_pose(deck)
	return deck.capture_pose(ids[ids.size() - 1])


func clear() -> void:
	_capacity = 0
	_next_index = 0
	for id in deck.get_ordered_ids():
		deck.remove_card(id, true, 0.0)


func _visual_target(deck_size: int) -> int:
	if deck_size <= 0:
		return 0
	if _capacity <= 0:
		return mini(DECK_VISUAL_MAX, deck_size)
	var scaled := int(ceil(float(deck_size) / float(_capacity) * float(DECK_VISUAL_MAX)))
	return clampi(scaled, 1, DECK_VISUAL_MAX)


func _make_stand_in(index: int) -> Card:
	var card := Card.new(
		CardEnums.Rank.NONE,
		CardEnums.Suit.CLUBS,
		CardInstanceId.from_string("deck_visual_%d" % index),
	)
	card.restrict_visibility_to([])
	return card
