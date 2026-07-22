class_name DeckVisibleMarkers
extends RefCounted
## Face-up deck cards (bottom wild / skill returns) rotated 90° under the pile.

const ID_PREFIX := "deck_visible_"
## Nudge so rotated cards stick out past the face-down pile.
const STICK_OUT := Vector2(36, 28)
const STICK_STEP := Vector2(10, 8)


## Visible deck entries for [param viewer_uid], in deck order.
## Each item: { "card": Card, "depth": int } where depth = cards before it.
static func list_visible(game_state: GameState, viewer_uid: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game_state == null or game_state.deck == null:
		return result
	var cards := game_state.deck.get_all_cards()
	for i in cards.size():
		var card: Card = cards[i]
		if card == null:
			continue
		if not card.can_be_viewed_by(viewer_uid):
			continue
		result.append({"card": card, "depth": i})
	return result


static func marker_id_for(instance_id: String) -> String:
	return "%s%s" % [ID_PREFIX, instance_id]


static func is_marker_id(id: String) -> bool:
	return id.begins_with(ID_PREFIX)


static func clear(deck_array: CardArray) -> void:
	if deck_array == null:
		return
	for id in deck_array.get_ordered_ids():
		if is_marker_id(id):
			deck_array.remove_card(id, true, 0.0)


## Sync face-up markers to match [method list_visible]. Returns visible count.
static func sync(
	deck_array: CardArray,
	game_state: GameState,
	viewer_uid: String,
) -> int:
	if deck_array == null:
		return 0
	var visible := list_visible(game_state, viewer_uid)
	if visible.is_empty():
		clear(deck_array)
		return 0

	var wanted: Dictionary = {} # marker_id -> true
	for entry in visible:
		var card: Card = entry["card"]
		wanted[marker_id_for(card.instance_id.value)] = true

	for id in deck_array.get_ordered_ids():
		if is_marker_id(id) and not wanted.has(id):
			deck_array.remove_card(id, true, 0.0)

	for entry in visible:
		var card: Card = entry["card"]
		var mid := marker_id_for(card.instance_id.value)
		var visual := card.duplicate_card()
		visual.instance_id = CardInstanceId.from_string(mid)
		visual.make_public()
		deck_array.add_card(visual, {}, 0.0, -1, true)

	# Markers under the pile (front); face-down stand-ins draw on top after them.
	var order_ids: Array[String] = []
	for order in visible.size():
		var card: Card = visible[order]["card"]
		order_ids.append(marker_id_for(card.instance_id.value))
	for id in deck_array.get_ordered_ids():
		if not is_marker_id(id):
			order_ids.append(id)
	deck_array.reorder_to(order_ids)
	_apply_poses(deck_array, visible)
	return visible.size()


## Put marker ids first (under the pile), then stand-ins.
static func reorder_under(deck_array: CardArray, visible: Array[Dictionary]) -> void:
	if deck_array == null:
		return
	var order_ids: Array[String] = []
	for entry in visible:
		var card: Card = entry["card"]
		if card == null:
			continue
		var mid := marker_id_for(card.instance_id.value)
		if deck_array.has_card(mid):
			order_ids.append(mid)
	for id in deck_array.get_ordered_ids():
		if not is_marker_id(id):
			order_ids.append(id)
	deck_array.reorder_to(order_ids)
	_apply_poses(deck_array, visible)


static func _apply_poses(deck_array: CardArray, visible: Array[Dictionary]) -> void:
	if deck_array == null:
		return
	for order in visible.size():
		var card: Card = visible[order]["card"]
		var view := deck_array.get_card_view(marker_id_for(card.instance_id.value))
		var base := view as CardBase
		if base == null:
			continue
		base.rotation_degrees = 90.0
		if not base.offset_transform_enabled:
			base.offset_transform_enabled = true
		# Peek out from under the face-down pile (markers are at the stack start).
		base.offset_transform_position = STICK_OUT + STICK_STEP * float(order)
		base.z_index = -1 - (visible.size() - 1 - order)
