class_name CharacterListData
extends Resource

const DchResource = preload("res://addons/dialogic/Resources/character.gd")

@export var characterListId: String = "chl-0"
@export var characterListName: String = "Unknown Character List"
@export var characters: Array[DchResource] = []


