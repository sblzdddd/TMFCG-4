@tool
extends Container
class_name CardInspector

@export var _preview: CardVisual
@export var _character_configurator: CardVisualEditor

func _ready() -> void:
	_character_configurator.character_data_changed.connect(_on_character_data_changed)

func _on_character_data_changed(data: CardVisualData) -> void:
	_preview.character = data
