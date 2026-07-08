# item_data.gd
class_name CardData
extends Resource

const Suit := CardEnums.Suit
const Rank := CardEnums.Rank
const Type := CardEnums.Type

@export var cardId: String = "card-0"
@export var visual: CardVisualData = null
@export var suit: Suit = Suit.CLUBS
@export var rank: Rank = Rank.NONE
@export var type: Type = Type.NORMAL
@export var skill_graph: Dictionary = {}
@export var skill_priority: int = 0
