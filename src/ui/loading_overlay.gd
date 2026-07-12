extends CanvasLayer

## Full-screen wipe that always slides right → left. Panel size tracks the viewport;
## corner radii adapt to the free edge while the sheet is mid-transition.

@export var tween_duration: float = 0.55
@export var max_corner_radius: float = 48.0
@export var panel_color: Color = Color(0.12156863, 0.12156863, 0.12156863, 1)
@export var size_padding: Vector2 = Vector2(64, 64)

@onready var _root: Control = $Root
@onready var _panel: Panel = $Root/Panel

var _style: StyleBoxFlat
var _tween: Tween
var _busy: bool = false
var _covering: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style = StyleBoxFlat.new()
	_style.bg_color = panel_color
	_style.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", _style)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.offset_transform_enabled = true
	visible = false
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_fit_panel_size()
	_park_offscreen_right()


func slide_in() -> void:
	await _slide(true)


func slide_out() -> void:
	await _slide(false)


## Re-assert a full cover after a scene swap so layout churn cannot clear the wipe.
func hold_cover() -> void:
	_covering = true
	visible = true
	_fit_panel_size()
	_panel.offset_transform_position.x = 0.0
	_adapt_radius(0.0)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _slide(covering: bool) -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	_fit_panel_size()
	var start_x: float
	var end_x: float
	if covering:
		_covering = true
		start_x = _offscreen_right_x()
		end_x = 0.0
		visible = true
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		end_x = _offscreen_left_x()
		hold_cover()
		start_x = 0.0
	_panel.offset_transform_position.x = start_x
	_adapt_radius(start_x)

	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "offset_transform_position:x", end_x, tween_duration)
	_tween.tween_method(_adapt_radius, start_x, end_x, tween_duration)
	await _tween.finished

	if not covering:
		_covering = false
		visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_park_offscreen_right()
	_busy = false


func _on_viewport_size_changed() -> void:
	_fit_panel_size()
	if _covering:
		_panel.offset_transform_position.x = 0.0
		visible = true
		_adapt_radius(0.0)


func _fit_panel_size() -> void:
	var vp := _viewport_size()
	if vp.x < 2.0 or vp.y < 2.0:
		return
	_panel.size = vp + size_padding
	_panel.position = -size_padding * 0.5


func _park_offscreen_right() -> void:
	_panel.offset_transform_position = Vector2(_offscreen_right_x(), 0)
	_adapt_radius(_panel.offset_transform_position.x)


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## Panel is oversized by [member size_padding]; travel past the viewport by half that
## overhang so rounded trailing edges never rest on-screen at tween end.
func _offscreen_right_x() -> float:
	return _viewport_size().x + size_padding.x * 0.5


func _offscreen_left_x() -> float:
	return -(_viewport_size().x + size_padding.x * 0.5)


func _adapt_radius(x_pos: float) -> void:
	if _style == null:
		return
	var left_r := 0.0
	var right_r := 0.0
	# Leading edge while entering from the right; trailing edge while exiting left.
	if x_pos > 0.0:
		left_r = minf(max_corner_radius, x_pos)
	elif x_pos < 0.0:
		right_r = minf(max_corner_radius, -x_pos)

	_style.corner_radius_top_left = int(left_r)
	_style.corner_radius_bottom_left = int(left_r)
	_style.corner_radius_top_right = int(right_r)
	_style.corner_radius_bottom_right = int(right_r)
