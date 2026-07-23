class_name PlayDecisionController
extends HBoxContainer
## Shows play/skip while local player is active.

@onready var _play_btn: Button = $PlayCardButton
@onready var _skip_btn: Button = $SkipButton
@onready var _active_hand: CardArray = %BottomActiveHand

var _selection := CardHandSelection.new()
var _active := false
var _hand_sig := ""
var _selection_valid := false


func _ready() -> void:
	visible = false
	_play_btn.pressed.connect(_on_play)
	_skip_btn.pressed.connect(_on_skip)
	_selection.selection_changed.connect(_refresh_play_enabled)
	_selection.bind(_active_hand)
	RoomSession.match_changed.connect(_on_match_changed)
	RoomSession.card_state_changed.connect(_on_card_state_changed)
	RoomSession.room_changed.connect(func(_r) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	if not _active or _active_hand == null:
		return
	var sig := ",".join(_active_hand.get_ordered_ids())
	if sig == _hand_sig:
		return
	_hand_sig = sig
	_selection.refresh()
	_refresh_play_enabled()


func _on_match_changed(_state: MatchRuntimeState) -> void:
	_refresh()


func _on_card_state_changed(_state: GameState) -> void:
	_hand_sig = "" # force rebind after sync
	_refresh()


func _refresh() -> void:
	var want := _should_be_active()
	if want != _active:
		_active = want
		_hand_sig = ""
		if not _active:
			_selection.clear()
	visible = _active
	_refresh_play_enabled()


func _should_be_active() -> bool:
	if PlayerDataStore.data == null or RoomSession.match_controller == null:
		return false
	var match_state := RoomSession.match_controller.get_state()
	if match_state == null or match_state.active_uid != PlayerDataStore.data.uid:
		return false
	return MatchPhase.is_play_phase(match_state.phase)


func _must_lead() -> bool:
	if PlayerDataStore.data == null or RoomSession.match_card_controller == null:
		return false
	var card_state := RoomSession.match_card_controller.get_state()
	return card_state != null and card_state.must_lead(PlayerDataStore.data.uid)


func _selected_cards() -> Array[Card]:
	var cards: Array[Card] = []
	if _active_hand == null or RoomSession.match_card_controller == null:
		return cards
	var state := RoomSession.match_card_controller.get_state()
	if state == null:
		return cards
	for id in _selection.get_selected_ids():
		var card := state.get_card_by_instance_id(id)
		if card != null:
			cards.append(card)
	return cards


func _selected_bases() -> Array:
	var bases: Array = []
	if _active_hand == null:
		return bases
	for id in _selection.get_selected_ids():
		var view := _active_hand.get_card_view(id)
		if view is CardBase:
			bases.append(view)
	return bases


func _refresh_play_enabled() -> void:
	var cards := _selected_cards()
	var state: GameState = null
	if RoomSession.match_card_controller != null:
		state = RoomSession.match_card_controller.get_state()
	_selection_valid = SelectionPlayLegality.is_valid_selection(cards, state)
	SelectionPlayLegality.apply_borders(_selected_bases(), _selection_valid)
	_play_btn.disabled = not _active or cards.is_empty() or not _selection_valid
	_skip_btn.disabled = not _active or _must_lead()


func _on_play() -> void:
	var ids := _selection.get_selected_ids()
	if ids.is_empty() or not _selection_valid or RoomSession.match_card_controller == null:
		return
	RoomSession.match_card_controller.send_play_request(ids)
	_selection.clear()


func _on_skip() -> void:
	if RoomSession.match_card_controller == null or _must_lead():
		return
	RoomSession.match_card_controller.send_pass_request()
	_selection.clear()
