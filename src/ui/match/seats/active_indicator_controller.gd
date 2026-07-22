class_name ActiveIndicatorController
extends Panel
## Highlights the active player's screen edge via asymmetric border widths.

const ACTIVE_BORDER := 200
const TWEEN_DURATION := 0.35

var _style: StyleBoxFlat
var _tween: Tween


func _ready() -> void:
	var base := get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		_style = (base as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		_style = StyleBoxFlat.new()
		_style.bg_color = Color(1, 1, 1, 0)
		_style.border_color = Color(1, 1, 1, 0.14117648)
		_style.border_blend = true
	_clear_borders()
	add_theme_stylebox_override("panel", _style)
	RoomSession.match_changed.connect(_on_match_changed)
	RoomSession.room_changed.connect(_on_room_changed)
	_refresh()


func _on_match_changed(_state: MatchRuntimeState) -> void:
	_refresh()


func _on_room_changed(_room: RoomData) -> void:
	_refresh()


func _refresh() -> void:
	if _style == null:
		return
	var targets := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if match_state != null and PlayerDataStore.data != null \
			and not match_state.active_uid.is_empty() \
			and match_state.phase != MatchPhase.Phase.INITIALIZATION:
		var seat := SeatLayout.seat_of(
			PlayerDataStore.data.uid,
			match_state.active_uid,
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
	_tween_borders(targets)


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
