# item_data.gd
class_name CardData
extends Resource

@export var cardId: String = "card-0"
@export var visual: CardVisualData = null
@export var suit: CardEnums.Suit = CardEnums.Suit.CLUBS
@export var rank: CardEnums.Rank = CardEnums.Rank.NONE
@export var type: CardEnums.Type = CardEnums.Type.NORMAL
