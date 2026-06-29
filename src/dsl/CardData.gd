# item_data.gd
class_name CardData
extends Resource
const Suit = preload("res://src/dsl/CardEnums.gd").Suit
const Rank = preload("res://src/dsl/CardEnums.gd").Rank
const Type = preload("res://src/dsl/CardEnums.gd").Type
const DchResource = preload("res://addons/dialogic/Resources/character.gd")

@export var cardId: String = "card-0"
@export var character: DchResource = null
@export var suit: Suit = Suit.CLUBS
@export var rank: Rank = Rank.NONE
@export var type: Type = Type.NORMAL
