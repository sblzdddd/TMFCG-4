class_name BombCombination
extends CardCombination

var length: int = 0


func _init(p_cards: Array[Card], p_power: int, p_length: int) -> void:
	cards = p_cards.duplicate()
	power = p_power
	length = p_length
