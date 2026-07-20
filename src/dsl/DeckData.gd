class_name DeckData
extends Resource

@export var id: String = "deck-0"
@export var name: String = "New Deck"
@export var author: String = "LC67"
@export var version: String = "1.0.0"
@export var date_created: float = Time.get_unix_time_from_system()
@export var date_modified: float = Time.get_unix_time_from_system()
@export var description: String = "A deck of cards"
@export var cards: Array[CardData] = []
