@tool
class_name UiCardEntry
extends Resource
## Row data for [UiCardList] / [UiCardItem] (not a poker card).

@export var id: String = "":
	set(value):
		if id == value:
			return
		id = value
		emit_changed()

@export var title: String = "":
	set(value):
		if title == value:
			return
		title = value
		emit_changed()

@export var subtitle: String = "":
	set(value):
		if subtitle == value:
			return
		subtitle = value
		emit_changed()

@export var action_text: String = "":
	set(value):
		if action_text == value:
			return
		action_text = value
		emit_changed()

@export var action_id: String = "":
	set(value):
		if action_id == value:
			return
		action_id = value
		emit_changed()

@export var icon: Texture2D:
	set(value):
		if icon == value:
			return
		icon = value
		emit_changed()

@export var draw_background: bool = true:
	set(value):
		if draw_background == value:
			return
		draw_background = value
		emit_changed()


func _init(
	p_id: String = "",
	p_title: String = "",
	p_subtitle: String = "",
	p_action_text: String = "",
	p_action_id: String = "",
	p_icon: Texture2D = null,
	p_draw_background: bool = true,
) -> void:
	id = p_id
	title = p_title
	subtitle = p_subtitle
	action_text = p_action_text
	action_id = p_action_id
	icon = p_icon
	draw_background = p_draw_background
