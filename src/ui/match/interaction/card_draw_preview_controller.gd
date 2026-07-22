class_name CardDrawPreviewController
extends PanelContainer
## Local draw: staggered deck→preview fly+flip, then auto-dismiss into hand.
## Empty soft-fills still show this overlay (no-draw message + countdown).
## Hold duration matches [constant MatchController.DRAW_PREVIEW_SEC].

const TITLE_DRAW := "抽卡结果"
const TITLE_EMPTY := "上轮出牌结束，本轮未抽牌"
const HINT_FMT := "%d秒后自动继续"
const PREVIEW_SIZE := Vector2(1100, 320)

@onready var _preview_array: CardArray = %CardsPreview
@onready var _coordinator: CardArrayCoordinator = %CardArrayCoordinator
@onready var _title_label: Label = %PreviewTitle
@onready var _hint_label: Label = %HintLabel

var _pending_ids: Array[String] = []
var _dismissing := false
var _preview_gen := 0
var _hint_secs := -1
var _empty_draw := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_array.horizontal = true
	RoomSession.cards_drawn.connect(_on_cards_drawn)


func _on_cards_drawn(card_ids: Array[String]) -> void:
	_preview_gen += 1
	var gen := _preview_gen
	_dismissing = false
	_pending_ids = card_ids.duplicate()
	_empty_draw = card_ids.is_empty()
	# Clock starts with cards_drawn — same moment the host begins DRAW_PREVIEW_SEC.
	var started_msec := Time.get_ticks_msec()
	_set_title(TITLE_EMPTY if _empty_draw else TITLE_DRAW)
	_set_hint_seconds(ceili(MatchController.DRAW_PREVIEW_SEC))
	if not _empty_draw:
		_coordinator.defer_hand_cards(_pending_ids)
		# Remote clients get cards_drawn before the snapshot lands; wait so preview
		# can resolve Card instances (with hydrated visuals) from state.
		await _wait_for_pending_cards(gen, started_msec)
		if gen != _preview_gen:
			return
	await _show_preview(gen, started_msec)


func _show_preview(gen: int, started_msec: int) -> void:
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	for id in _preview_array.get_ordered_ids():
		await _preview_array.remove_card(id, true, 0.0)
	if gen != _preview_gen:
		return

	var cards: Array[Card] = []
	if not _empty_draw:
		cards = _pending_cards()
	if cards.is_empty():
		_empty_draw = true
		_set_title(TITLE_EMPTY)
		_preview_array.visible = false
		_preview_array.custom_minimum_size = Vector2.ZERO
		await _await_countdown(gen, started_msec)
		if gen != _preview_gen:
			return
		await _dismiss()
		return

	_preview_array.visible = true
	_preview_array.custom_minimum_size = PREVIEW_SIZE
	var deck_pose := _coordinator.get_deck_draw_pose()
	_preview_array.reset_stagger()
	for card in cards:
		var delay := _preview_array.next_stagger_delay()
		var view := _preview_array.add_flippable_card(card, deck_pose, delay)
		# Flip starts with the fly (same stagger), not after it.
		_schedule_flip(view, delay)

	# Live countdown runs through fly-in + hold, synced to DRAW_PREVIEW_SEC.
	await _await_countdown(gen, started_msec)
	if gen != _preview_gen:
		return
	await _dismiss()


func _await_countdown(gen: int, started_msec: int) -> void:
	while gen == _preview_gen:
		var remain := _refresh_hint(started_msec)
		if remain <= 0.0:
			return
		await get_tree().process_frame


func _refresh_hint(started_msec: int) -> float:
	var elapsed := (Time.get_ticks_msec() - started_msec) / 1000.0
	var remain := maxf(0.0, MatchController.DRAW_PREVIEW_SEC - elapsed)
	_set_hint_seconds(ceili(remain) if remain > 0.0 else 0)
	return remain


func _set_title(text: String) -> void:
	if _title_label == null:
		return
	_title_label.text = text


func _set_hint_seconds(secs: int) -> void:
	if _hint_label == null or secs == _hint_secs:
		return
	_hint_secs = secs
	_hint_label.text = HINT_FMT % secs


func _wait_for_pending_cards(gen: int, started_msec: int, timeout_sec: float = 2.0) -> void:
	if _pending_cards().size() >= _pending_ids.size():
		_refresh_hint(started_msec)
		return
	var deadline_msec := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline_msec and gen == _preview_gen:
		_refresh_hint(started_msec)
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


func _dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var poses: Dictionary = {}
	for id in _pending_ids:
		var pose := _preview_array.capture_pose(id)
		# Hand fly-out must stay above the fading overlay (dest is not under preview).
		if not pose.is_empty():
			pose["fly_z"] = CardPose.PREVIEW_FLY_Z_INDEX
		poses[id] = pose
		if _preview_array.has_card(id):
			_preview_array.remove_card(id, false, 0.0)
	if not _pending_ids.is_empty():
		_coordinator.release_deferred_hand_cards(poses)
	_pending_ids.clear()
	var tw := CardAnim.init_fade_out_tween(self)
	tw.tween_property(self, "modulate:a", 0.0, CardAnim.fade_out_duration())
	await tw.finished
	if not is_instance_valid(self):
		return
	visible = false
	modulate.a = 1.0
	_hint_secs = -1
	_empty_draw = false
	_preview_array.visible = true
	_preview_array.custom_minimum_size = PREVIEW_SIZE
	_dismissing = false
