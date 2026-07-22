class_name StraightCombination
extends CardCombination

var length: int = 0


func _init(p_cards: Array[Card] = [], p_power: int = 0, p_length: int = -1) -> void:
	cards = p_cards.duplicate()
	power = p_power
	length = p_length if p_length >= 0 else cards.size()


func compare_to(other: CardCombination) -> int:
	if other == null:
		return 1
	if other is BombCombination:
		return -1
	if not other is StraightCombination:
		return -1
	var o := other as StraightCombination
	# Longer straights always beat shorter ones.
	if length != o.length:
		return length - o.length
	return power - o.power
