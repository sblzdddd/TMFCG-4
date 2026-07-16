class_name UiCardEntry
extends Resource
## Row data for [UiCardList] / [UiCardItem] (not a poker card).

@export var id: String = ""
@export var title: String = ""
@export var subtitle: String = ""
@export var action_text: String = ""
@export var action_id: String = ""
@export var icon: Texture2D


func _init(
	p_id: String = "",
	p_title: String = "",
	p_subtitle: String = "",
	p_action_text: String = "",
	p_action_id: String = "",
	p_icon: Texture2D = null,
) -> void:
	id = p_id
	title = p_title
	subtitle = p_subtitle
	action_text = p_action_text
	action_id = p_action_id
	icon = p_icon
