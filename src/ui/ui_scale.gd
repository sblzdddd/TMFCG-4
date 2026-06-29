extends Node

## Keeps the UI readable on HiDPI displays and when the window is smaller than the design size.
## Stretch mode scales canvas items down for small windows; this autoload raises
## [member Window.content_scale_factor] to compensate and apply OS display scaling.

signal scale_changed(factor: float)

const DESIGN_SIZE := Vector2i(1920, 1080)
const REFERENCE_DPI := 96.0
const MIN_WINDOW_SIZE := Vector2i(800, 600)

var scale_factor: float = 1.0
var dpi_scale: float = 1.0
var window_boost: float = 1.0


func _ready() -> void:
	var window := get_window()
	window.min_size = MIN_WINDOW_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.size_changed.connect(_apply_scale)
	_apply_scale()


func _apply_scale() -> void:
	var window := get_window()
	var window_size := window.get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return

	dpi_scale = _get_display_scale(window.current_screen)
	window_boost = _get_window_boost(window_size)
	var new_factor := dpi_scale * window_boost

	if is_equal_approx(scale_factor, new_factor):
		return

	scale_factor = new_factor
	window.content_scale_factor = scale_factor
	scale_changed.emit(scale_factor)


static func _get_display_scale(screen: int) -> float:
	var os_scale := DisplayServer.screen_get_scale(screen)
	if os_scale > 0.0:
		return os_scale

	var dpi := DisplayServer.screen_get_dpi(screen)
	if dpi > 0:
		return maxf(1.0, float(dpi) / REFERENCE_DPI)

	return 1.0


static func _get_window_boost(window_size: Vector2i) -> float:
	var width_ratio := float(window_size.x) / float(DESIGN_SIZE.x)
	var height_ratio := float(window_size.y) / float(DESIGN_SIZE.y)
	var shrink := minf(width_ratio, height_ratio)
	if shrink >= 1.0:
		return 1.0
	return 1.0 / shrink
