class_name TurnCountdownController
extends Node
## Local turn countdown bars. Each client tracks remaining time after active_uid
## changes and shrinks the seat panel via offset_transform_scale.x. Local timeout
## sends pass (or auto-plays when must-lead). Host grace is +10s in MatchController.

@onready var _left: Control = %LeftPlayerCountdown
@onready var _top: Control = %TopPlayerCountdown
@onready var _right: Control = %RightPlayerCountdown
@onready var _bottom: Control = %BottomPlayerCountdown

var _active_uid := ""
var _started_msec := 0
var _duration_sec := 0.0
var _timed_out := false


func _ready() -> void:
	for panel in [_left, _top, _right, _bottom]:
		_prepare_panel(panel)
	RoomSession.match_changed.connect(_on_match_changed)
	RoomSession.room_changed.connect(_on_room_changed)
	_sync_from_match()


func _process(_delta: float) -> void:
	if _active_uid.is_empty() or _duration_sec <= 0.0:
		return
	var remain := _remaining_sec()
	_apply_visual(remain / _duration_sec)
	if remain > 0.0 or _timed_out:
		return
	_timed_out = true
	_on_local_timeout()


func _on_match_changed(_state: MatchRuntimeState) -> void:
	_sync_from_match()


func _on_room_changed(_room: RoomData) -> void:
	if _active_uid.is_empty():
		return
	var new_dur := _turn_countdown_sec()
	if is_equal_approx(new_dur, _duration_sec):
		return
	_duration_sec = new_dur
	_timed_out = false


func _sync_from_match() -> void:
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	var uid := ""
	if (
		match_state != null
		and MatchPhase.is_play_phase(match_state.phase)
		and not match_state.active_uid.is_empty()
	):
		uid = match_state.active_uid
	if uid == _active_uid:
		return
	_active_uid = uid
	_timed_out = false
	if uid.is_empty():
		_duration_sec = 0.0
		_apply_visual(0.0)
		return
	_duration_sec = _turn_countdown_sec()
	_started_msec = Time.get_ticks_msec()
	_apply_visual(1.0)


func _turn_countdown_sec() -> float:
	if RoomSession.match_controller != null:
		return RoomSession.match_controller.turn_countdown_sec()
	if RoomSession.current_room != null:
		return float(RoomSession.current_room.turn_countdown_sec)
	return MatchController.DEFAULT_TURN_COUNTDOWN_SEC


func _remaining_sec() -> float:
	var elapsed := (Time.get_ticks_msec() - _started_msec) / 1000.0
	return maxf(0.0, _duration_sec - elapsed)


func _apply_visual(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var seat := _active_seat()
	_set_scale_x(_left, clamped if seat == SeatLayout.Seat.LEFT else 0.0)
	_set_scale_x(_top, clamped if seat == SeatLayout.Seat.TOP else 0.0)
	_set_scale_x(_right, clamped if seat == SeatLayout.Seat.RIGHT else 0.0)
	_set_scale_x(_bottom, clamped if seat == SeatLayout.Seat.BOTTOM else 0.0)


func _active_seat() -> SeatLayout.Seat:
	if _active_uid.is_empty() or PlayerDataStore.data == null:
		return SeatLayout.Seat.NONE
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if match_state == null or match_state.order == null:
		return SeatLayout.Seat.NONE
	return SeatLayout.seat_of(PlayerDataStore.data.uid, _active_uid, match_state.order)


func _on_local_timeout() -> void:
	if PlayerDataStore.data == null or _active_uid != PlayerDataStore.data.uid:
		return
	if RoomSession.match_card_controller == null:
		return
	var card_state := RoomSession.match_card_controller.get_state()
	if card_state != null and card_state.must_lead(_active_uid):
		var hand := card_state.get_player_hand(PlayerId.from_string(_active_uid))
		if hand == null or hand.get_size() <= 0:
			return
		var card := hand.get_card(0)
		if card == null:
			return
		RoomSession.match_card_controller.send_play_request([card.instance_id.value])
		return
	RoomSession.match_card_controller.send_pass_request()


func _prepare_panel(panel: Control) -> void:
	if panel == null:
		return
	panel.offset_transform_enabled = true
	panel.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	panel.offset_transform_scale = Vector2(0.0, 1.0)


func _set_scale_x(panel: Control, x: float) -> void:
	if panel == null:
		return
	var cur := panel.offset_transform_scale
	if is_equal_approx(cur.x, x):
		return
	panel.offset_transform_scale = Vector2(x, cur.y)
