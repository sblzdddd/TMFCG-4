class_name CardInfoInteraction
extends RefCounted
## Hover-delay / touch-hold card info popup for a [CardBase].

const HOLD_TIMEOUT := 0.4
const ACTIVE_HAND_HOVER_DELAY := 1.0

var skills_only: bool = true
var hover_delay: float = 0.0

var _host: CardBase
var _hold_timer: Timer
var _hover_timer: Timer
var _touch_holding := false
var _info_shown_by_hold := false
var _showing_info := false


var touch_holding: bool:
	get:
		return _touch_holding


func setup(host: CardBase) -> void:
	_host = host
	_hold_timer = Timer.new()
	_hold_timer.name = "InfoHoldTimer"
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_TIMEOUT
	host.add_child(_hold_timer)
	_hold_timer.timeout.connect(_on_hold_timeout)
	_hover_timer = Timer.new()
	_hover_timer.name = "InfoHoverTimer"
	_hover_timer.one_shot = true
	host.add_child(_hover_timer)
	_hover_timer.timeout.connect(_on_hover_timeout)


func can_show() -> bool:
	if _host == null:
		return false
	var data := _host.get_card_data()
	if data == null or not _host.is_face_up():
		return false
	if skills_only and data.type != CardEnums.Type.SKILL:
		return false
	return true


func on_hover_entered() -> void:
	# Defer so an emulated touch down in this frame can claim the hold path first.
	call_deferred("_deferred_try_show_on_hover")


func _deferred_try_show_on_hover() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if not _host.is_hovering() or _touch_holding:
		return
	if hover_delay > 0.0:
		_hover_timer.stop()
		_hover_timer.wait_time = hover_delay
		_hover_timer.start()
		return
	_show_if_possible()


func on_hover_exited() -> void:
	if _hover_timer != null:
		_hover_timer.stop()
	if not _touch_holding:
		hide_info()


func begin_touch_hold() -> void:
	if _touch_holding:
		return
	_touch_holding = true
	_info_shown_by_hold = false
	if _hover_timer != null:
		_hover_timer.stop()
	hide_info()
	if _hold_timer != null:
		_hold_timer.stop()
		if can_show():
			_hold_timer.start()


## Returns true when the release should count as a press (not an info-hold dismiss).
func end_touch_hold() -> bool:
	if not _touch_holding:
		return false
	if _hold_timer != null:
		_hold_timer.stop()
	var was_info_hold := _info_shown_by_hold
	_touch_holding = false
	_info_shown_by_hold = false
	if was_info_hold:
		hide_info()
		return false
	return true


func hide_info() -> void:
	if not _showing_info:
		return
	_showing_info = false
	CardInfoPanel.hide_popup(_host)


func _on_hover_timeout() -> void:
	if _host == null or not _host.is_hovering() or _touch_holding or not can_show():
		return
	_show_if_possible()


func _on_hold_timeout() -> void:
	if not _touch_holding or not can_show():
		return
	_info_shown_by_hold = true
	_show_if_possible(true)


func _show_if_possible(from_hold: bool = false) -> void:
	if not can_show():
		return
	_showing_info = true
	var anchor := _host.get_global_rect() if from_hold else Rect2()
	CardInfoPanel.show_card(_host.get_card_data(), anchor, _host)
