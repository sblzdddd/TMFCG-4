class_name CardViewFactory
extends RefCounted
## Instantiates match card views (CardBase / card_back).

const CARD_BASE_SCENE := preload("res://definitions/prefabs/card_base.tscn")
const CARD_BACK_SCENE := preload("res://definitions/prefabs/card_back.tscn")
const META_INSTANCE_ID := "match_instance_id"


static func make_base(card: Card, face_up: bool) -> CardBase:
	var base := CARD_BASE_SCENE.instantiate() as CardBase
	base.interactable = false
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_data(base, card)
	base.set_face_up(face_up, false)
	base.refresh_interaction()
	return base


static func make_back(instance_id: String) -> Control:
	var back := CARD_BACK_SCENE.instantiate() as Control
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_meta(META_INSTANCE_ID, instance_id)
	return back


static func apply_data(base: CardBase, card: Card) -> void:
	base.set_meta(META_INSTANCE_ID, card.instance_id.value)
	if card.data != null:
		base.set_card_data(card.data)
	base.refresh_interaction()
