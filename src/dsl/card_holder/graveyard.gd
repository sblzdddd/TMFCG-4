class_name Graveyard
extends CardHolder

const HOLDER_ID := "graveyard"


func _init(p_cards: Array[Card] = []) -> void:
	super._init(Kind.GRAVEYARD, HOLDER_ID, p_cards)


static func from_dict(dict: Dictionary) -> Graveyard:
	return Graveyard.new(CardHolder.cards_from_dict(dict))
