class_name PlayDecisionController
extends HBoxContainer
## Shows play/skip while local player is active.

@onready var _play_btn: Button = $PlayCardButton
@onready var _skip_btn: Button = $SkipButton
@onready var _active_hand: CardArray = %BottomActiveHand

var _selection := CardHandSelection.new()
var _active := false
var _hand_sig := ""


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
	return (
		match_state != null
		and match_state.phase == MatchPhase.Phase.TURN_PLAY
		and match_state.active_uid == PlayerDataStore.data.uid
	)


func _must_lead() -> bool:
	if PlayerDataStore.data == null or RoomSession.match_card_controller == null:
		return false
	var card_state := RoomSession.match_card_controller.get_state()
	return card_state != null and card_state.must_lead(PlayerDataStore.data.uid)


func _refresh_play_enabled() -> void:
	_play_btn.disabled = not _active or _selection.get_selected_ids().is_empty()
	# Trick winner must play a card to lead unless they have no cards.
	_skip_btn.disabled = not _active or _must_lead()


func _on_play() -> void:
	var ids := _selection.get_selected_ids()
	if ids.is_empty() or RoomSession.match_card_controller == null:
		return
	RoomSession.match_card_controller.send_play_request(ids)
	_selection.clear()


func _on_skip() -> void:
	if RoomSession.match_card_controller == null or _must_lead():
		return
	RoomSession.match_card_controller.send_pass_request()
	_selection.clear()
