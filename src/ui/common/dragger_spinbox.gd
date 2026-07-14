@tool
extends SpinBox
class_name DraggerSpinBox

## Inspector-style spinbox with horizontal drag to adjust, tap/click to type.

const _FLOAT_DRAG_SPEED := 0.5
const _INTEGER_DRAG_SPEED := 0.1
const _MIN_FLOAT_STEP := 0.001
const _DRAG_THRESHOLD_SCALE := 4.0

enum _GrabInput { NONE, MOUSE, TOUCH }
enum _ProgressState { IDLE, HOVER, DRAG }

@export var label_text: String = "Value":
	set(value):
		if label_text == value:
			return
		label_text = value
		_sync_label()

@export var label_settings: LabelSettings:
	set(value):
		if label_settings == value:
			return
		_disconnect_label_settings()
		label_settings = value
		_connect_label_settings()
		_sync_label()

@export_group("Progress Styles")
@export var progress_style_idle: StyleBoxFlat
@export var progress_style_hover: StyleBoxFlat
@export var progress_style_drag: StyleBoxFlat

const _LABEL_PADDING := 8.0

@onready var _overlay: Control = $DragOverlay
@onready var _progress_fill: Panel = $DragOverlay/ProgressFill
@onready var _label: Label = $DragOverlay/Label

var _progress_state := _ProgressState.IDLE
var _grab_attempt := false
var _grabbing := false
var _pre_grab_value := 0.0
var _grab_mouse_pos := Vector2.ZERO
var _grab_dist_cache := 0.0
var _grab_input := _GrabInput.NONE
var _grab_touch_index := -1


func _enter_tree() -> void:
	_hook_line_edit()
	_hook_overlay()


func _ready() -> void:
	set_process_input(false)
	call_deferred(&"_finalize_overlay")


func _finalize_overlay() -> void:
	_hook_line_edit()
	_hook_overlay()
	_connect_label_settings()
	_sync_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_overlay()


func _hook_overlay() -> void:
	if _overlay == null:
		return
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _overlay.gui_input.is_connected(_on_overlay_gui_input):
		_overlay.gui_input.connect(_on_overlay_gui_input)
	if not _overlay.mouse_entered.is_connected(_on_overlay_mouse_entered):
		_overlay.mouse_entered.connect(_on_overlay_mouse_entered)
	if not _overlay.mouse_exited.is_connected(_on_overlay_mouse_exited):
		_overlay.mouse_exited.connect(_on_overlay_mouse_exited)


func _hook_line_edit() -> void:
	var line_edit := get_line_edit()
	if line_edit == null:
		return
	if not line_edit.focus_exited.is_connected(_on_line_edit_focus_exited):
		line_edit.focus_exited.connect(_on_line_edit_focus_exited)
	if not line_edit.editing_toggled.is_connected(_on_line_edit_editing_toggled):
		line_edit.editing_toggled.connect(_on_line_edit_editing_toggled)
	if not value_changed.is_connected(_on_value_changed_display):
		value_changed.connect(_on_value_changed_display)
	if not changed.is_connected(_on_range_changed):
		changed.connect(_on_range_changed)


func _on_range_changed() -> void:
	_sync_progress_fill()


func _step_decimals(step_size: float) -> int:
	if step_size <= 0.0 or step_size >= 1.0:
		return 0
	var count := 0
	var probe := step_size
	while count < 6 and not is_zero_approx(probe - roundf(probe)):
		probe *= 10.0
		count += 1
	return count


func _effective_step() -> float:
	var current_step := step if step > 0.0 else 1.0
	if rounded:
		return current_step
	return maxf(current_step, _MIN_FLOAT_STEP)


func _quantize_value(v: float) -> float:
	if rounded:
		return round(v)
	return snapped(v, _effective_step())


func _format_display_value(v: float) -> String:
	var quantized := _quantize_value(v)
	var text := str(int(quantized)) if rounded else String.num(quantized, _step_decimals(_effective_step()))
	if not prefix.is_empty():
		text = prefix + " " + text
	if not suffix.is_empty():
		text += " " + suffix
	return text


func _refresh_display() -> void:
	var line_edit := get_line_edit()
	if line_edit == null or line_edit.is_editing():
		return
	line_edit.set_text(_format_display_value(value))


func _on_value_changed_display(_new_value: float) -> void:
	_refresh_display()
	_sync_progress_fill()


func _is_ranged() -> bool:
	return max_value > min_value


func _is_keyboard_editing() -> bool:
	var line_edit := get_line_edit()
	return line_edit != null and line_edit.is_editing()


func _progress_fill_ratio() -> float:
	var range_size := max_value - min_value
	if is_zero_approx(range_size):
		return 0.0
	return clampf((value - min_value) / range_size, 0.0, 1.0)


func _progress_style_for(state: _ProgressState) -> StyleBoxFlat:
	match state:
		_ProgressState.DRAG:
			return progress_style_drag
		_ProgressState.HOVER:
			return progress_style_hover
	return progress_style_idle


func _set_progress_state(state: _ProgressState) -> void:
	if _progress_state == state:
		return
	_progress_state = state
	_sync_progress_fill()


func _sync_progress_fill() -> void:
	if _progress_fill == null or _overlay == null:
		return
	if not _is_ranged() or _is_keyboard_editing():
		_progress_fill.visible = false
		return

	var fill_ratio := _progress_fill_ratio()
	var style := _progress_style_for(_progress_state)
	if style == null:
		_progress_fill.visible = false
		return

	_progress_fill.visible = true
	_progress_fill.position = Vector2.ZERO
	_progress_fill.size = Vector2(_overlay.size.x * fill_ratio, _overlay.size.y)
	_progress_fill.add_theme_stylebox_override(&"panel", style)


func _connect_label_settings() -> void:
	if not is_instance_valid(label_settings) or not is_instance_valid(_label):
		return
	if not label_settings.changed.is_connected(_on_label_settings_changed):
		label_settings.changed.connect(_on_label_settings_changed)


func _disconnect_label_settings() -> void:
	if not is_instance_valid(label_settings):
		return
	if label_settings.changed.is_connected(_on_label_settings_changed):
		label_settings.changed.disconnect(_on_label_settings_changed)


func _on_label_settings_changed() -> void:
	_sync_label()


func _sync_label() -> void:
	if _label == null or _overlay == null:
		return
	_label.text = label_text
	_label.visible = not label_text.is_empty()
	if is_instance_valid(label_settings):
		_label.label_settings = label_settings
	_label.position = Vector2(_LABEL_PADDING, 0.0)
	_label.size = Vector2(maxf(_overlay.size.x - _LABEL_PADDING * 2.0, 0.0), _overlay.size.y)


func _sync_overlay() -> void:
	if _overlay == null:
		return
	var line_edit := get_line_edit()
	if line_edit == null:
		return
	_overlay.set_position(line_edit.position)
	_overlay.set_size(line_edit.size)
	_overlay.visible = editable
	_overlay.move_to_front()
	_sync_label()
	_sync_progress_fill()


func _set_overlay_blocking(block: bool) -> void:
	if _overlay == null:
		return
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE


func _drag_speed() -> float:
	return _INTEGER_DRAG_SPEED if rounded else _FLOAT_DRAG_SPEED


func _grab_start(input: _GrabInput, touch_index: int = -1) -> void:
	_grab_attempt = true
	_grabbing = false
	_grab_dist_cache = 0.0
	_pre_grab_value = value
	_grab_input = input
	_grab_touch_index = touch_index
	if input == _GrabInput.MOUSE:
		_grab_mouse_pos = get_global_mouse_position()
		set_process_input(true)


func _grab_end() -> void:
	if not _grab_attempt:
		return

	var was_grabbing := _grabbing
	if was_grabbing:
		_grabbing = false
		if _grab_input == _GrabInput.MOUSE:
			_restore_mouse_pos()
		_refresh_display()
		_set_progress_state(_ProgressState.HOVER if _overlay.get_global_rect().has_point(get_global_mouse_position()) else _ProgressState.IDLE)
	else:
		_set_overlay_blocking(false)
		var line_edit := get_line_edit()
		if line_edit != null:
			line_edit.grab_focus()

	_grab_attempt = false
	_grab_input = _GrabInput.NONE
	_grab_touch_index = -1
	set_process_input(false)


func _restore_mouse_pos() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(2).timeout
	Input.warp_mouse(_grab_mouse_pos * get_window().content_scale_factor)

func _apply_drag(relative_x: float, shift_pressed: bool, round_to_int: bool) -> void:
	var speed := _drag_speed()
	var diff_x := relative_x
	if shift_pressed:
		diff_x *= 0.1
	_grab_dist_cache += diff_x * speed

	var threshold := _DRAG_THRESHOLD_SCALE * speed
	if not _grabbing and absf(_grab_dist_cache) > threshold:
		if _grab_input == _GrabInput.MOUSE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_grabbing = true
		_set_progress_state(_ProgressState.DRAG)

	if not _grabbing:
		return

	var new_value := _quantize_value(_pre_grab_value + _effective_step() * _grab_dist_cache)
	if round_to_int and not rounded:
		new_value = round(new_value)
	set_value(clampf(new_value, min_value, max_value))


func _on_overlay_gui_input(event: InputEvent) -> void:
	if not editable:
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_grab_start(_GrabInput.MOUSE)
			_overlay.accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_grab_start(_GrabInput.TOUCH, touch.index)
			_overlay.accept_event()
		elif _grab_attempt and _grab_input == _GrabInput.TOUCH and touch.index == _grab_touch_index:
			_grab_end()
			_overlay.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _grab_attempt and _grab_input == _GrabInput.TOUCH and drag.index == _grab_touch_index:
			_apply_drag(drag.relative.x, false, false)
			_overlay.accept_event()


func _on_overlay_mouse_entered() -> void:
	if not _grabbing and not _is_keyboard_editing():
		_set_progress_state(_ProgressState.HOVER)


func _on_overlay_mouse_exited() -> void:
	if not _grabbing:
		_set_progress_state(_ProgressState.IDLE)


func _input(event: InputEvent) -> void:
	if not _grab_attempt or _grab_input != _GrabInput.MOUSE:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_apply_drag(
			motion.relative.x,
			motion.shift_pressed,
			motion.ctrl_pressed or motion.meta_pressed
		)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_grab_end()
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed and _grabbing:
			_cancel_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.is_action(&"ui_cancel") and _grabbing:
			_cancel_drag()
			get_viewport().set_input_as_handled()


func _cancel_drag() -> void:
	set_value(_pre_grab_value)
	_grab_end()


func _on_line_edit_focus_exited() -> void:
	_set_overlay_blocking(true)
	_sync_progress_fill()


func _on_line_edit_editing_toggled(editing: bool) -> void:
	if not editing:
		_set_overlay_blocking(true)
	_sync_progress_fill()
