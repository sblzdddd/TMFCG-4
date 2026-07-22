class_name MatchDebugPanel
extends VBoxContainer
## Host-only mock controls for match order / phase / card draws.

@onready var _next_btn: Button = %DebugNextPlayer
@onready var _offset_btn: Button = %DebugOffsetPlayer
@onready var _reverse_btn: Button = %DebugReverseOrder
@onready var _end_round_btn: Button = %DebugEndRound
@onready var _end_game_btn: Button = %DebugEndGamePlay
@onready var _draw_all_btn: Button = %DebugDrawAll
@onready var _draw_count: DraggerSpinBox = %DebugDrawCount
@onready var _draw_bottom_btn: Button = %DebugDrawBottom
@onready var _draw_left_btn: Button = %DebugDrawLeft
@onready var _draw_top_btn: Button = %DebugDrawTop
@onready var _draw_right_btn: Button = %DebugDrawRight


func _ready() -> void:
	_next_btn.pressed.connect(_on_next)
	_offset_btn.pressed.connect(_on_offset)
	_reverse_btn.pressed.connect(_on_reverse)
	_end_round_btn.pressed.connect(_on_end_round)
	_end_game_btn.pressed.connect(_on_end_game)
	_draw_all_btn.pressed.connect(_on_draw_all)
	_draw_bottom_btn.pressed.connect(_on_draw_bottom)
	_draw_left_btn.pressed.connect(_on_draw_left)
	_draw_top_btn.pressed.connect(_on_draw_top)
	_draw_right_btn.pressed.connect(_on_draw_right)
	RoomSession.room_changed.connect(_on_room_changed)
	RoomSession.match_changed.connect(_on_match_changed)
	_refresh_visibility()


func _on_room_changed(_room: RoomData) -> void:
	_refresh_visibility()


func _on_match_changed(_state: MatchRuntimeState) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = RoomSession.is_local_host() and RoomSession.current_room != null


func _ctrl() -> MatchController:
	return RoomSession.match_controller


func _cards() -> MatchCardController:
	return RoomSession.match_card_controller


func _on_next() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.advance_turn()


func _on_offset() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.offset_active(1)


func _on_reverse() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.reverse_order()


func _on_end_round() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.end_round()


func _on_end_game() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.end_game_play()


func _on_draw_all() -> void:
	var cards := _cards()
	if cards:
		cards.draw_for_all_soft()


func _on_draw_bottom() -> void:
	_draw_for_seat(SeatLayout.Seat.BOTTOM)


func _on_draw_left() -> void:
	_draw_for_seat(SeatLayout.Seat.LEFT)


func _on_draw_top() -> void:
	_draw_for_seat(SeatLayout.Seat.TOP)


func _on_draw_right() -> void:
	_draw_for_seat(SeatLayout.Seat.RIGHT)


func _draw_count_value() -> int:
	if _draw_count == null:
		return 1
	return maxi(1, int(_draw_count.value))


func _draw_for_seat(seat: SeatLayout.Seat) -> void:
	var cards := _cards()
	if cards == null:
		return
	var uid := _uid_for_seat(seat)
	if uid.is_empty():
		return
	cards.draw_to_player(uid, _draw_count_value())


func _uid_for_seat(seat: SeatLayout.Seat) -> String:
	if PlayerDataStore.data == null:
		return ""
	var local_uid := PlayerDataStore.data.uid
	if seat == SeatLayout.Seat.BOTTOM:
		return local_uid
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if match_state == null:
		return ""
	var seats := SeatLayout.resolve(local_uid, match_state.order)
	match seat:
		SeatLayout.Seat.LEFT:
			return str(seats.get("left", ""))
		SeatLayout.Seat.TOP:
			return str(seats.get("top", ""))
		SeatLayout.Seat.RIGHT:
			return str(seats.get("right", ""))
		_:
			return ""
