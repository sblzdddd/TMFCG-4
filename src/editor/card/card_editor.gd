@tool
extends Control
class_name CardEditor

@export var _inspector: CardInspector
@export var _file_tree: EditorFileTree
@export var _add_deck_button: Button
@export var _add_character_button: Button
@export var _create_deck_dialog: CreateDeckDialog
@export var _create_character_dialog: CreateCharacterDialog


func _ready() -> void:
	ResourceFsUtils.ensure_user_dirs()
	_add_deck_button.pressed.connect(_create_deck_dialog.popup_dialog)
	_add_character_button.pressed.connect(_create_character_dialog.popup_dialog)
	_create_deck_dialog.deck_created.connect(_on_deck_created)
	_create_character_dialog.character_created.connect(_on_character_created)


func _on_deck_created(deck: DeckData, path: String) -> void:
	_file_tree.add_deck_item(deck, path)


func _on_character_created(character: DialogicCharacter, path: String) -> void:
	_file_tree.add_character_item(character, path)
