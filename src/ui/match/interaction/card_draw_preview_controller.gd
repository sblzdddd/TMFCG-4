class_name CardDrawPreviewController
extends PanelContainer
## Local draw: staggered deck→preview fly+flip together; click → staggered fly to hand.

@onready var _preview_array: CardArray = %CardsPreview
@onready var _coordinator: CardArrayCoordinator = %CardArrayCoordinator

var _pending_ids: Array[String] = []
var _awaiting_click := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_array.horizontal = true
	RoomSession.cards_drawn.connect(_on_cards_drawn)
	gui_input.connect(_on_gui_input)


func _on_cards_drawn(card_ids: Array[String]) -> void:
	if card_ids.is_empty():
		return
	_pending_ids = card_ids.duplicate()
	_coordinator.defer_hand_cards(_pending_ids)
	# Remote clients get cards_drawn before the snapshot lands; wait so preview
	# can resolve Card instances (with hydrated visuals) from state.
	await _wait_for_pending_cards()
	await _show_preview()


func _show_preview() -> void:
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	_awaiting_click = false
	for id in _preview_array.get_ordered_ids():
		await _preview_array.remove_card(id, true, 0.0)

	var cards := _pending_cards()
	if cards.is_empty():
		visible = false
		_coordinator.release_deferred_hand_cards({})
		_pending_ids.clear()
		return
	var deck_pose := _coordinator.get_deck_draw_pose()
	_preview_array.reset_stagger()
	for card in cards:
		var delay := _preview_array.next_stagger_delay()
		var view := _preview_array.add_flippable_card(card, deck_pose, delay)
		# Flip starts with the fly (same stagger), not after it.
		_schedule_flip(view, delay)

	var last_delay := maxf(0.0, float(cards.size() - 1) * CardAnim.stagger_delay())
	await get_tree().create_timer(
		last_delay + CardAnim.move_duration() + CardAnim.flip_duration()
	).timeout
	_awaiting_click = true


func _wait_for_pending_cards(timeout_sec: float = 2.0) -> void:
	if _pending_cards().size() >= _pending_ids.size():
		return
	var deadline_msec := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
		if _pending_cards().size() >= _pending_ids.size():
			return


func _schedule_flip(view: CardBase, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if is_instance_valid(view):
				view.flip_to_face(0.0),
		CONNECT_ONE_SHOT,
	)


func _pending_cards() -> Array[Card]:
	var state: GameState = null
	if RoomSession.match_card_controller != null:
		state = RoomSession.match_card_controller.get_state()
	if state == null:
		state = _coordinator.last_state
	var cards: Array[Card] = []
	if state == null or PlayerDataStore.data == null:
		return cards
	var hand := state.get_player_hand(PlayerId.from_string(PlayerDataStore.data.uid))
	if hand == null:
		return cards
	for id in _pending_ids:
		for card in hand.get_all_cards():
			if card.instance_id.value == id:
				cards.append(card)
				break
	return cards


func _on_gui_input(event: InputEvent) -> void:
	if not _awaiting_click or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_dismiss()


func _input(event: InputEvent) -> void:
	if not _awaiting_click or not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		_dismiss()


func _dismiss() -> void:
	if not _awaiting_click:
		return
	_awaiting_click = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var poses: Dictionary = {}
	for id in _pending_ids:
		poses[id] = _preview_array.capture_pose(id)
		if _preview_array.has_card(id):
			_preview_array.remove_card(id, false, 0.0)
	_coordinator.release_deferred_hand_cards(poses)
	_pending_ids.clear()
	var tw := CardAnim.init_fade_out_tween(self)
	tw.tween_property(self, "modulate:a", 0.0, CardAnim.fade_out_duration())
	await tw.finished
	if not is_instance_valid(self):
		return
	visible = false
	modulate.a = 1.0
