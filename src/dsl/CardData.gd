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


func _init() -> void:
	_migrate_legacy_rank()


func _migrate_legacy_rank() -> void:
	if int(rank) == CardEnums.LEGACY_WILD_VALUE:
		rank = Rank.WILD


func to_card() -> Card:
	_migrate_legacy_rank()
	return Card.from_data(duplicate(true) as CardData)


func apply_from_card(card: Card) -> void:
	suit = card.suit
	rank = card.rank
	if card.data != null and not card.data.cardId.is_empty():
		cardId = card.data.cardId
