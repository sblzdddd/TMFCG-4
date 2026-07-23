class_name ActiveIndicatorController
extends Panel
## Highlights the active player's screen edge via asymmetric border widths.
## Trick-winner lead uses yellow; after they play, border returns to white.

const ACTIVE_BORDER := 200
const TWEEN_DURATION := 0.35
const BORDER_WHITE := Color(1, 1, 1, 0.14117648)
const BORDER_YELLOW := Color(1, 0.85, 0.2, 0.55)

var _style: StyleBoxFlat
var _tween: Tween
var _color_tween: Tween


func _ready() -> void:
	var base := get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		_style = (base as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		_style = StyleBoxFlat.new()
		_style.bg_color = Color(1, 1, 1, 0)
		_style.border_color = BORDER_WHITE
		_style.border_blend = true
	_clear_borders()
	add_theme_stylebox_override("panel", _style)
	RoomSession.match_changed.connect(_on_match_changed)
	RoomSession.card_state_changed.connect(_on_card_state_changed)
	RoomSession.room_changed.connect(_on_room_changed)
	_refresh()


func _on_match_changed(_state: MatchRuntimeState) -> void:
	_refresh()


func _on_card_state_changed(_state: GameState) -> void:
	_refresh()


func _on_room_changed(_room: RoomData) -> void:
	_refresh()


func _refresh() -> void:
	if _style == null:
		return
	var targets := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	var highlight_uid := ""
	var yellow := false
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	var card_state: GameState = null
	if RoomSession.match_card_controller != null:
		card_state = RoomSession.match_card_controller.get_state()
	var awaiting_lead := card_state != null and card_state.is_awaiting_lead()
	var winner_uid := (
		card_state.trick_winner_id.value
		if card_state != null and card_state.trick_winner_id != null
		else ""
	)
	if match_state != null and PlayerDataStore.data != null \
			and match_state.phase != MatchPhase.Phase.INITIALIZATION:
		if match_state.phase == MatchPhase.Phase.ROUND_RESOLUTION and awaiting_lead:
			highlight_uid = winner_uid
			yellow = true
		elif (
			MatchPhase.is_play_phase(match_state.phase)
			and not match_state.active_uid.is_empty()
		):
			highlight_uid = match_state.active_uid
			yellow = awaiting_lead and highlight_uid == winner_uid
		if not highlight_uid.is_empty():
			var seat := SeatLayout.seat_of(
				PlayerDataStore.data.uid,
				highlight_uid,
				match_state.order,
			)
			match seat:
				SeatLayout.Seat.LEFT:
					targets["left"] = ACTIVE_BORDER
				SeatLayout.Seat.TOP:
					targets["top"] = ACTIVE_BORDER
				SeatLayout.Seat.RIGHT:
					targets["right"] = ACTIVE_BORDER
				SeatLayout.Seat.BOTTOM:
					targets["bottom"] = ACTIVE_BORDER
				_:
					pass
	_tween_border_color(BORDER_YELLOW if yellow else BORDER_WHITE)
	_tween_borders(targets)


func _tween_border_color(color: Color) -> void:
	if _style.border_color.is_equal_approx(color):
		return
	_color_tween = TweenUtils.init_tween(self, _color_tween, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_color_tween.tween_property(_style, "border_color", color, TWEEN_DURATION)


func _tween_borders(targets: Dictionary) -> void:
	if (
		_style.border_width_left == targets["left"]
		and _style.border_width_top == targets["top"]
		and _style.border_width_right == targets["right"]
		and _style.border_width_bottom == targets["bottom"]
	):
		return
	_tween = TweenUtils.init_tween(self, _tween, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_style, "border_width_left", float(targets["left"]), TWEEN_DURATION)
	_tween.tween_property(_style, "border_width_top", float(targets["top"]), TWEEN_DURATION)
	_tween.tween_property(_style, "border_width_right", float(targets["right"]), TWEEN_DURATION)
	_tween.tween_property(_style, "border_width_bottom", float(targets["bottom"]), TWEEN_DURATION)


func _clear_borders() -> void:
	_style.border_width_left = 0
	_style.border_width_top = 0
	_style.border_width_right = 0
	_style.border_width_bottom = 0
	_style.border_color = BORDER_WHITE
