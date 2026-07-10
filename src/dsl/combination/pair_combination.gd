class_name PairCombination
extends CardCombination


func _init(p_cards: Array[Card], p_power: int) -> void:
	cards = p_cards.duplicate()
	power = p_power
