extends ColorRect
class_name CardVisual

enum BorderState { NORMAL, HOVER, ACTIVE }

const FALLBACK_PORTRAIT := preload("res://assets/textures/characters/Fallback.png")
const BORDER_NORMAL := preload("res://definitions/ui/card/card_border_normal.tres")
const BORDER_HOVER := preload("res://definitions/ui/card/card_border_hover.tres")
const BORDER_ACTIVE := preload("res://definitions/ui/card/card_border_active.tres")

@onready var _value_label_a: Label = $ValueLabel
@onready var _value_label_b: Label = $ValueLabel2
@onready var _name_label: CurvedText = $CharacterNameLabel
@onready var _border: Panel = get_node_or_null("Border") as Panel

var _character_data: CardVisualData = null
var _card_data: CardData = null
var _portrait_texture: Texture2D = null
var _suit_layer_texture: Texture2D = null
var _border_state: BorderState = BorderState.NORMAL

var name_label: CurvedText:
	get:
		return _name_label

@export var card: CardData:
	get:
		return _card_data
	set(value):
		_card_data = value
		if is_node_ready():
			_update_card_face()

@export var character: CardVisualData:
	get:
		return _character_data
	set(value):
		_character_data = value
		if is_node_ready():
			_update_character(value)

func _update_character(data: CardVisualData) -> void:
	if data == null or data.character == null:
		_name_label.text = "-"
		_set_character_texture(null)
		_set_character_transform(Vector3(0, 0, 1))
		return

	_name_label.text = data.character.get_translated_name("en")
	_set_character_texture(
		data.character.load_portrait_texture(data.portrait)
	)
	_set_character_transform(data.transform)

func _update_card_face() -> void:
	var rank_text := "-"
	var suit_value := CardEnums.Suit.CLUBS
	var rank_value := CardEnums.Rank.NONE
	if _card_data != null:
		rank_text = CardUtils.rank_display(_card_data.rank)
		suit_value = _card_data.suit
		rank_value = _card_data.rank

	_value_label_a.text = rank_text
	_value_label_b.text = rank_text

	_set_suit_layer_texture(CardUtils.load_baked_suit_texture(suit_value, rank_value))

func set_border_state(state: BorderState) -> void:
	_border_state = state
	if not is_node_ready():
		return
	_apply_border_style()

func _apply_border_style() -> void:
	var border := _border
	if border == null:
		border = get_node_or_null("Border") as Panel
	if border == null:
		return
	var style: StyleBox
	match _border_state:
		BorderState.HOVER:
			style = BORDER_HOVER
		BorderState.ACTIVE:
			style = BORDER_ACTIVE
		_:
			style = BORDER_NORMAL
	border.add_theme_stylebox_override("panel", style)

func _set_suit_layer_texture(texture: Texture2D) -> void:
	if _suit_layer_texture == texture:
		return
	_suit_layer_texture = texture

	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("suitLayerTex", texture)

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
	_update_card_face()
	_update_character(_character_data)
	_apply_border_style()
