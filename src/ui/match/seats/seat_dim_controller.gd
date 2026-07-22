class_name SeatDimController
extends Node
## Dims inactive seats' hands/graveyards (and the deck); active seat stays full bright.

const TWEEN_DUR := 0.35
const DIM_BRIGHTNESS := 0.72
const FULL_BRIGHTNESS := 1.0

@onready var _left_hand: Control = %LeftHand
@onready var _left_gy: Control = %LeftGraveyard
@onready var _top_hand: Control = %TopHand
@onready var _top_gy: Control = %TopGraveyard
@onready var _deck: Control = %Deck
@onready var _bottom_hand: Control = %BottomHand
@onready var _bottom_active: Control = %BottomActiveHand
@onready var _bottom_gy: Control = %BottomGraveyard
@onready var _right_hand: Control = %RightHand
@onready var _right_gy: Control = %RightGraveyard

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
	_dim_seat(SeatLayout.Seat.LEFT, active, [_left_hand, _left_gy])
	_dim_seat(SeatLayout.Seat.TOP, active, [_top_hand, _top_gy])
	_dim_seat(SeatLayout.Seat.RIGHT, active, [_right_hand, _right_gy])
	_dim_seat(
		SeatLayout.Seat.BOTTOM, active, [_bottom_hand, _bottom_active, _bottom_gy]
	)
	# Shared pile — always dimmed once a turn is underway.
	var deck_brightness := (
		DIM_BRIGHTNESS if active != SeatLayout.Seat.NONE else FULL_BRIGHTNESS
	)
	_tween_brightness(_deck, deck_brightness)


func _dim_seat(seat: SeatLayout.Seat, active: SeatLayout.Seat, nodes: Array) -> void:
	var brightness := FULL_BRIGHTNESS
	if active != SeatLayout.Seat.NONE and seat != active:
		brightness = DIM_BRIGHTNESS
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
