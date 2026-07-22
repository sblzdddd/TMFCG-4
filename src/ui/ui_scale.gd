extends Node

## Smart global UI scaler.
## Small screens: shrink by resolution so the UI still fits.
## Large screens: grow by resolution so the UI scales up with the window.
## HiDPI: physical (DPI / OS) scale is a floor so design-size windows still bump up.

const BASE_DPI := 96.0
const DEFAULT_BASE_SIZE := Vector2(1152.0, 648.0)
const MIN_SCALE := 0.5
const MAX_SCALE := 3.0
## Extra physical-scale factor on Web (browser DPI / devicePixelRatio quirks).
const WEB_PHYSICAL_MULT := 1.25

## Last applied content scale factor.
var scale_factor: float = 1.0
## Multiplier on large-screen scale only. Small screens ignore it.
var physical_scale_multiplier: float = 1.0:
	get:
		return _physical_scale_multiplier
	set(value):
		var next := maxf(value, 0.01)
		if is_equal_approx(_physical_scale_multiplier, next):
			return
		_physical_scale_multiplier = next
		if is_inside_tree():
			apply_scale()

var _physical_scale_multiplier: float = 1.0

func _ready() -> void:
	var window := _root_window()
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size_changed.connect(apply_scale)
	# Window size can still be unsettled on the first frame (esp. Windows).
	apply_scale.call_deferred()


func _notification(what: int) -> void:
	# Re-evaluate when focus returns (e.g. window moved to another monitor).
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		apply_scale()


func apply_scale() -> void:
	var window := _root_window()
	if window == null:
		return
	var base := _get_base_size()
	var window_size := Vector2(window.size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var scale_res := minf(window_size.x / base.x, window_size.y / base.y)
	var scale_phys := _get_physical_scale()

	# Small window: must shrink to fit.
	# Large / design-size window: grow with resolution, with DPI as a floor so
	# hiDPI still scales up when the window is only about design-sized.
	#   2560x1440 @ 125% DPI, base 1280x720 → max(2.0, 1.25) = 2.0
	#   1280x720  @ 125% DPI                 → max(1.0, 1.25) = 1.25
	#   640x360   @ 125% DPI                 → 0.5
	var target: float
	if scale_res < 1.0:
		target = scale_res
	else:
		target = maxf(scale_res, scale_phys) * physical_scale_multiplier

	scale_factor = clampf(target, MIN_SCALE, MAX_SCALE)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = scale_factor


func _root_window() -> Window:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root


func _get_base_size() -> Vector2:
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height := float(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	if width <= 0.0 or height <= 0.0:
		return DEFAULT_BASE_SIZE
	return Vector2(width, height)


func _get_physical_scale() -> float:
	var screen := DisplayServer.window_get_current_screen()
	var os_scale := DisplayServer.screen_get_scale(screen)
	var dpi := float(DisplayServer.screen_get_dpi(screen))
	var dpi_scale := dpi / BASE_DPI if dpi > 0.0 else 1.0
	# screen_get_scale is authoritative on macOS / Wayland / mobile; on
	# Windows / X11 it often returns 1.0, so take the larger of the two.
	var scale := maxf(os_scale if os_scale > 0.0 else 1.0, dpi_scale)
	if OS.has_feature("web"):
		scale *= WEB_PHYSICAL_MULT
	return scale
