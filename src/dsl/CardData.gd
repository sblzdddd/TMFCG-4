# item_data.gd
class_name CardData
extends Resource

const _card_enums := preload("res://src/dsl/CardEnums.gd")

@export var cardId: String = "card-0"
@export var visual: CardVisualData = null
@export var suit: _card_enums.Suit = _card_enums.Suit.CLUBS
@export var rank: _card_enums.Rank = _card_enums.Rank.NONE
@export var type: _card_enums.Type = _card_enums.Type.NORMAL
