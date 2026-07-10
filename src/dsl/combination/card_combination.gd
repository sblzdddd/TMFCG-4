class_name CardCombination
extends RefCounted

var cards: Array[Card] = []
var power: int = 0


func compare_to(other: CardCombination) -> int:
	if self is BombCombination and not other is BombCombination:
		return power
	if get_script() == other.get_script():
		return power - other.power
	return -1
