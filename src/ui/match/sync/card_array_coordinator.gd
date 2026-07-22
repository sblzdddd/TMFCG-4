class_name CardArrayCoordinator
extends Node
## Diffs GameState holders into seat CardArrays; cross-array moves via poses.

@onready var _deck_stack: DeckVisualStack = %DeckVisualStack
@onready var _left_hand: CardArray = %LeftHand
@onready var _left_gy: CardArray = %LeftGraveyard
@onready var _top_hand: CardArray = %TopHand
@onready var _top_gy: CardArray = %TopGraveyard
@onready var _bottom_gy: CardArray = %BottomGraveyard
@onready var _bottom_hand: CardArray = %BottomHand
@onready var _bottom_active_hand: CardArray = %BottomActiveHand
@onready var _right_gy: CardArray = %RightGraveyard
@onready var _right_hand: CardArray = %RightHand

var _seats := CardSeatMap.new()
var _deferred_hand_ids: Dictionary = {} # String -> true
var last_state: GameState = null
var _ui_locations: Dictionary = {} # instance_id -> holder_id
var _sync_gen := 0
var _apply_queued := false


func _ready() -> void:
	_seats.bind(
		_left_hand, _left_gy, _top_hand, _top_gy,
		_bottom_gy, _bottom_hand, _bottom_active_hand, _right_gy, _right_hand,
	)
	RoomSession.card_state_changed.connect(_on_card_state_changed)
	RoomSession.match_changed.connect(func(_s) -> void: _reapply())
	RoomSession.room_changed.connect(func(_r) -> void: _reapply())


func defer_hand_cards(instance_ids: Array[String]) -> void:
	for id in instance_ids:
		_deferred_hand_ids[id] = true


func release_deferred_hand_cards(poses_by_id: Dictionary = {}) -> void:
	var ids: Array[String] = []
	for id in _deferred_hand_ids.keys():
		ids.append(str(id))
	_deferred_hand_ids.clear()
	if last_state == null or ids.is_empty():
		return
	var hand := last_state.get_player_hand(PlayerId.from_string(_seats.local_uid()))
	var target := _seats.array_for(_seats.local_uid())
	if target == null:
		target = _bottom_hand
	target.reset_stagger()
	for id in ids:
		var card := _find_card(hand, id)
		if card == null:
			continue
		target.add_card(card, poses_by_id.get(id, {}), target.next_stagger_delay(), -1, true)
		_ui_locations[id] = hand.holder_id


func get_deck_draw_pose() -> Dictionary:
	return _deck_stack.draw_pose()


func _on_card_state_changed(state: GameState) -> void:
	if state == null:
		_apply_queued = false
		_clear_all_ui()
		return
	last_state = state
	_queue_apply()


func _reapply() -> void:
	if last_state != null:
		_queue_apply()


func _queue_apply() -> void:
	if _apply_queued: return
	_apply_queued = true
	call_deferred("_flush_apply")


func _flush_apply() -> void:
	_apply_queued = false
	if last_state != null:
		_apply_state(last_state)

func _apply_state(state: GameState) -> void:
	last_state = state
	_sync_gen += 1
	var gen := _sync_gen
	var desired := _build_desired(state)
	var poses: Dictionary = {}
	# 1) Snapshot movers while old views are still in place.
	var movers: Array[Dictionary] = []
	for id in _ui_locations.keys():
		var old_holder := str(_ui_locations[id])
		var new_holder := str(desired.get(id, ""))
		var target := _seats.array_for(new_holder) if not new_holder.is_empty() else null
		if new_holder == old_holder and target != null and target.has_card(id):
			continue
		movers.append({"id": id, "old": old_holder, "new": new_holder})
	for m in movers:
		var id: String = m["id"]
		var old_holder: String = m["old"]
		var new_holder: String = m["new"]
		if old_holder == Deck.HOLDER_ID:
			poses[id] = _deck_stack.draw_pose()
			continue
		var to_nowhere := new_holder.is_empty() or new_holder == Graveyard.HOLDER_ID
		if to_nowhere:
			continue
		var arr := _seats.find_array_with(id)
		if arr != null:
			poses[id] = arr.capture_pose(id)
	# 2) Remove all instantly (no stagger) so cards don't vanish before fly-ins.
	for m in movers:
		if gen != _sync_gen:
			return
		var id: String = m["id"]
		var old_holder: String = m["old"]
		var new_holder: String = m["new"]
		_ui_locations.erase(id)
		if old_holder == Deck.HOLDER_ID:
			continue
		var arr := _seats.find_array_with(id)
		if arr == null:
			continue
		var to_nowhere := new_holder.is_empty() or new_holder == Graveyard.HOLDER_ID
		arr.remove_card(id, to_nowhere, 0.0)
	if gen != _sync_gen:
		return
	# 3) Add into targets; fly from captured poses (stagger only starts the flight).
	for arr in _seats.play_arrays():
		arr.reset_stagger()
	for holder_id in _seats.holder_sync_order():
		if gen != _sync_gen:
			return
		var arr := _seats.array_for(holder_id)
		var holder := state.get_holder(holder_id)
		if arr == null or holder == null:
			continue
		var is_local := holder_id == _seats.local_uid()
		for card in holder.get_all_cards():
			var id := card.instance_id.value
			if is_local and _deferred_hand_ids.has(id):
				continue
			if arr.has_card(id):
				_ui_locations[id] = holder_id
				continue
			var pose: Dictionary = poses.get(id, {})
			if pose.is_empty() and _seats.is_player_hand(holder_id):
				pose = _deck_stack.draw_pose()
			arr.add_card(
				card, pose, arr.next_stagger_delay(), -1, card.can_be_viewed_by(_seats.local_uid())
			)
			_ui_locations[id] = holder_id
	for arr in _seats.play_arrays():
		for id in arr.get_ordered_ids():
			if gen != _sync_gen:
				return
			if desired.has(id):
				_ui_locations[id] = str(desired[id])
			elif not _deferred_hand_ids.has(id):
				arr.remove_card(id, true, 0.0)
				_ui_locations.erase(id)
	if gen == _sync_gen:
		await _deck_stack.sync_size(state.deck.get_size())


func _clear_all_ui() -> void:
	last_state = null
	_ui_locations.clear()
	_deferred_hand_ids.clear()
	_deck_stack.clear()
	for arr in _seats.play_arrays():
		for id in arr.get_ordered_ids():
			arr.remove_card(id, true, 0.0)


func _build_desired(state: GameState) -> Dictionary:
	var result: Dictionary = {}
	for holder in state.all_card_holders():
		if holder.kind == CardHolder.Kind.GRAVEYARD or holder.kind == CardHolder.Kind.DECK:
			continue
		for card in holder.get_all_cards():
			result[card.instance_id.value] = holder.holder_id
	return result


func _find_card(hand: CardHolder, id: String) -> Card:
	for card in hand.get_all_cards():
		if card.instance_id.value == id:
			return card
	return null
