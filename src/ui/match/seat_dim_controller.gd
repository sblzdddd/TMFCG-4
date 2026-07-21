class_name SeatDimController
extends Node
## Dims seat chrome + card arrays by table-ring distance from the active seat.

const TWEEN_DUR := 0.35

@onready var _left_hand: Control = %LeftHand
@onready var _left_gy: Control = %LeftGraveyard
@onready var _left_seat: Control = %LeftPlayer
@onready var _top_hand: Control = %TopHand
@onready var _top_gy: Control = %TopGraveyard
@onready var _top_card: Control = %TopPlayerCard
@onready var _top_buff: Control = %TopPlayerBuff
@onready var _bottom_hand: Control = %BottomHand
@onready var _bottom_active: Control = %BottomActiveHand
@onready var _bottom_gy: Control = %BottomGraveyard
@onready var _right_hand: Control = %RightHand
@onready var _right_gy: Control = %RightGraveyard
@onready var _right_seat: Control = %RightPlayer

var _tweens: Dictionary = {} # Control -> Tween


func _ready() -> void:
	RoomSession.match_changed.connect(func(_s) -> void: _refresh())
	RoomSession.room_changed.connect(func(_r) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	var active := SeatLayout.Seat.NONE
	if (
		match_state != null
		and PlayerDataStore.data != null
		and not match_state.active_uid.is_empty()
		and match_state.phase != MatchPhase.Phase.INITIALIZATION
	):
		active = SeatLayout.seat_of(
			PlayerDataStore.data.uid, match_state.active_uid, match_state.order
		)
	_dim_group(SeatLayout.Seat.LEFT, active, [_left_hand, _left_gy, _left_seat])
	_dim_group(SeatLayout.Seat.TOP, active, [_top_hand, _top_gy, _top_card, _top_buff])
	_dim_group(SeatLayout.Seat.RIGHT, active, [_right_hand, _right_gy, _right_seat])
	_dim_group(
		SeatLayout.Seat.BOTTOM, active, [_bottom_hand, _bottom_active, _bottom_gy]
	)


func _dim_group(seat: SeatLayout.Seat, active: SeatLayout.Seat, nodes: Array) -> void:
	var brightness := 1.0
	if active != SeatLayout.Seat.NONE:
		brightness = SeatLayout.dim_brightness(SeatLayout.ring_distance(active, seat))
	for node in nodes:
		if node is Control:
			_tween_brightness(node as Control, brightness)


func _tween_brightness(control: Control, brightness: float) -> void:
	# Only RGB — bottom GY hide uses modulate.a.
	if (
		is_equal_approx(control.modulate.r, brightness)
		and is_equal_approx(control.modulate.g, brightness)
		and is_equal_approx(control.modulate.b, brightness)
	):
		return
	var prev: Tween = _tweens.get(control) as Tween
	var tw := TweenUtils.init_tween(control, prev, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tweens[control] = tw
	tw.set_parallel(true)
	tw.tween_property(control, "modulate:r", brightness, TWEEN_DUR)
	tw.tween_property(control, "modulate:g", brightness, TWEEN_DUR)
	tw.tween_property(control, "modulate:b", brightness, TWEEN_DUR)
