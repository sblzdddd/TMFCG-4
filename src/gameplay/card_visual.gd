extends ColorRect
class_name CardVisual

const FALLBACK_PORTRAIT := preload("res://assets/textures/characters/Fallback.png")

@export var valueLabels: Array[Label] = []
@export var _name_label: CurvedText

var _character_data: CardCharacterData = null
var _portrait_texture: Texture2D = null

@export var character: CardCharacterData:
	set(value):
		_character_data = value
		if is_node_ready():
			_update_visual(value)

func _update_visual(data: CardCharacterData) -> void:
	if data == null or data.character == null:
		_name_label.text = "-"
		_set_character_texture(null)
		_set_character_transform(Vector3(0, 0, 1))
		return

	_name_label.text = CharacterUtils.get_english_display_name(data.character)
	_set_character_texture(
		CharacterUtils.load_portrait_texture(data.character, data.selected_portrait)
	)
	_set_character_transform(data.transform)

func _set_character_texture(texture: Texture2D) -> void:
	var resolved := texture if texture else FALLBACK_PORTRAIT
	if _portrait_texture == resolved:
		return
	_portrait_texture = resolved

	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("characterTex", resolved)

func _set_character_transform(transform: Vector3) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("characterTransform", transform)

func _ready() -> void:
	material = material.duplicate()
	for label in valueLabels:
		label.label_settings = valueLabels[0].label_settings.duplicate()
	_update_visual(_character_data)
