class_name DeckVisualStack
extends Node
## Capped deck stand-in stack. Shrinks from top only; not 1:1 with draws.
## Viewer-visible deck cards (bottom wild / skill returns) use face-up 90° markers.

const DECK_VISUAL_MAX := 10
## Padding around union of card rects so hover covers stick-outs / rotation.
const HOVER_PAD := Vector2(56, 48)
const HOVER_MIN := Vector2(160, 120)

@onready var deck: CardArray = %Deck
@onready var _hover_hit: Control = get_node_or_null("%DeckHoverHit") as Control
@onready var _visible_list: DeckVisibleListPopup = get_node_or_null("%DeckVisibleList") as DeckVisibleListPopup

var _capacity := 0
var _next_index := 0
var _visible_count := 0
var _visible_entries: Array[Dictionary] = []
var _viewer_uid := ""
var _pile: Control = null


func _ready() -> void:
	if deck != null:
		_pile = deck.get_parent() as Control
	if _pile != null:
		_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hover_hit != null:
		_hover_hit.mouse_filter = Control.MOUSE_FILTER_STOP
		_hover_hit.mouse_entered.connect(_on_deck_hover_entered)
		_hover_hit.mouse_exited.connect(_on_deck_hover_exited)


func sync_size(
	deck_size: int,
	game_state: GameState = null,
	viewer_uid: String = "",
) -> void:
	_viewer_uid = viewer_uid
	if deck_size > 0 and _capacity <= 0:
		_capacity = deck_size
	if deck_size > 0:
		_visible_entries = DeckVisibleMarkers.list_visible(game_state, viewer_uid)
		_visible_count = DeckVisibleMarkers.sync(deck, game_state, viewer_uid)
	else:
		DeckVisibleMarkers.clear(deck)
		_visible_count = 0
		_visible_entries.clear()
	if _visible_list != null:
		_visible_list.set_entries(_visible_entries)
		if _visible_entries.is_empty():
			_visible_list.hide_list()
	var target := _visual_target(deck_size)
	var current := _stand_in_count()
	while current < target:
		var stand_in := _make_stand_in(_next_index)
		_next_index += 1
		# Append on top of the pile; markers stay at the front (under).
		deck.add_card(stand_in, {}, 0.0, -1, false)
		current += 1
	while current > target:
		var ids := deck.get_ordered_ids()
		var remove_id := ""
		for i in range(ids.size() - 1, -1, -1):
			if not DeckVisibleMarkers.is_marker_id(ids[i]):
				remove_id = ids[i]
				break
		if remove_id.is_empty():
			break
		await deck.remove_card(remove_id, true, 0.0)
		current -= 1
	if _visible_count > 0:
		DeckVisibleMarkers.reorder_under(deck, _visible_entries)
	await get_tree().process_frame
	_fit_hover_to_cards()


func draw_pose() -> Dictionary:
	var ids := deck.get_ordered_ids()
	if ids.is_empty():
		return CardPose.origin_pose(deck)
	for i in range(ids.size() - 1, -1, -1):
		if not DeckVisibleMarkers.is_marker_id(ids[i]):
			return deck.capture_pose(ids[i])
	return deck.capture_pose(ids[ids.size() - 1])


func clear() -> void:
	_capacity = 0
	_next_index = 0
	_visible_count = 0
	_visible_entries.clear()
	if _visible_list != null:
		_visible_list.hide_list()
		_visible_list.set_entries([])
	for id in deck.get_ordered_ids():
		deck.remove_card(id, true, 0.0)
	_fit_hover_to_cards()


func _stand_in_count() -> int:
	var n := 0
	for id in deck.get_ordered_ids():
		if not DeckVisibleMarkers.is_marker_id(id):
			n += 1
	return n


func _visual_target(deck_size: int) -> int:
	if deck_size <= 0:
		return 0
	var max_stand := DECK_VISUAL_MAX - _visible_count
	max_stand = maxi(max_stand, 1)
	var hidden := maxi(deck_size - _visible_count, 0)
	if hidden <= 0:
		return 0
	if _capacity <= 0:
		return mini(max_stand, hidden)
	var scaled := int(ceil(float(deck_size) / float(_capacity) * float(max_stand)))
	return clampi(scaled, 1, max_stand)


func _make_stand_in(index: int) -> Card:
	var card := Card.new(
		CardEnums.Rank.NONE,
		CardEnums.Suit.CLUBS,
		CardInstanceId.from_string("deck_visual_%d" % index),
	)
	card.restrict_visibility_to([])
	return card


## Expand DeckPile so hover (full-rect child) covers the card stack + stick-outs.
func _fit_hover_to_cards() -> void:
	if _pile == null or _hover_hit == null or deck == null:
		return
	var bounds := _card_bounds_in_pile()
	var need := HOVER_MIN
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		var padded := bounds.grow_individual(HOVER_PAD.x, HOVER_PAD.y, HOVER_PAD.x, HOVER_PAD.y)
		need = Vector2(
			maxi(ceili(padded.size.x), int(HOVER_MIN.x)),
			maxi(ceili(padded.size.y), int(HOVER_MIN.y)),
		)
	_pile.custom_minimum_size = need
	# Full-rect hit over the pile (ignore layout min quirks on the Deck container).
	_hover_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hover_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hover_hit.z_index = 5


func _card_bounds_in_pile() -> Rect2:
	if _pile == null or deck == null:
		return Rect2()
	var first := true
	var union := Rect2()
	for id in deck.get_ordered_ids():
		var view := deck.get_card_view(id)
		if view == null or not is_instance_valid(view):
			continue
		var top_left := _pile.get_global_transform_with_canvas().affine_inverse() * view.get_global_transform_with_canvas() * Vector2.ZERO
		var bottom_right := _pile.get_global_transform_with_canvas().affine_inverse() * view.get_global_transform_with_canvas() * view.size
		var r := Rect2(top_left, bottom_right - top_left).abs()
		# Rotated markers: include axis-aligned bounds of the four corners.
		if absf(view.rotation_degrees) > 0.01:
			r = _transformed_aabb_in_pile(view)
		if first:
			union = r
			first = false
		else:
			union = union.merge(r)
	return union if not first else Rect2()


func _transformed_aabb_in_pile(view: Control) -> Rect2:
	var inv := _pile.get_global_transform_with_canvas().affine_inverse()
	var xf := view.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		inv * xf * Vector2(0, 0),
		inv * xf * Vector2(view.size.x, 0),
		inv * xf * Vector2(0, view.size.y),
		inv * xf * Vector2(view.size.x, view.size.y),
	]
	var r := Rect2(corners[0], Vector2.ZERO)
	for i in range(1, corners.size()):
		r = r.expand(corners[i])
	return r


func _on_deck_hover_entered() -> void:
	if _visible_list == null or _visible_entries.is_empty():
		return
	_visible_list.show_list()


func _on_deck_hover_exited() -> void:
	if _visible_list != null:
		_visible_list.hide_list()
