class_name CardCombinationSerde
extends RefCounted
## Light snapshot of a trick combo (type + power + length). Cards omitted.


static func to_dict(combo: CardCombination) -> Dictionary:
	if combo == null:
		return {}
	var type_name := "SINGLE"
	var length := 0
	if combo is BombCombination:
		type_name = "BOMB"
		length = (combo as BombCombination).length
	elif combo is PairCombination:
		type_name = "PAIR"
	elif combo is StraightCombination:
		type_name = "STRAIGHT"
		length = (combo as StraightCombination).length
	return {
		"type": type_name,
		"power": combo.power,
		"length": length,
	}


static func from_dict(dict: Dictionary) -> CardCombination:
	if dict.is_empty():
		return null
	var power := int(dict.get("power", 0))
	var length := int(dict.get("length", 0))
	var empty: Array[Card] = []
	match str(dict.get("type", "")).to_upper():
		"BOMB":
			return BombCombination.new(empty, power, length)
		"PAIR":
			return PairCombination.new(empty, power)
		"STRAIGHT":
			return StraightCombination.new(empty, power, length)
		"SINGLE":
			return SingleCombination.new(empty, power)
		_:
			return null
