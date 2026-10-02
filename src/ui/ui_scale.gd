extends Node

## Global UI scaler via Window.content_scale_factor.
## - Shrinks when the window is below design size.
## - Grows with resolution on larger windows.
## - Desktop (Windows / Linux): DPI / OS scale is a floor at design size+.
## - macOS / mobile: window.size is already backing / density pixels, so the
##   DPI floor is skipped to avoid double-counting.

const BASE_DPI := 96.0
## UI design reference — keep independent of project viewport size so raising
## viewport_width for rendering does not shrink the interface on Windows.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const MIN_SCALE := 0.5
const MAX_SCALE := 3.0
const WEB_PHYSICAL_MULT := 1.25

## Last applied content scale factor.
var scale_factor: float = 1.0
## User-facing display scale from settings (1.0 = 100%).
var base_scale: float = 1.0:
	get:
		return _base_scale
	set(value):
		var next := clampf(value, MIN_SCALE, MAX_SCALE)
		if is_equal_approx(_base_scale, next):
			return
		_base_scale = next
		if is_inside_tree():
			apply_scale()

## Multiplier on large-screen desktop scale only.
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

var _base_scale: float = 1.0
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
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree():
		apply_scale()


func apply_scale() -> void:
	var window := _root_window()
	if window == null:
		return
	var window_size := Vector2(window.size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var scale_res := minf(window_size.x / DESIGN_SIZE.x, window_size.y / DESIGN_SIZE.y)
	var target := scale_res
	# Examples @ DESIGN_SIZE 1280x720:
	#   2560x1440 @ 125% DPI → max(2.0, 1.25) = 2.0
	#   1280x720  @ 125% DPI → max(1.0, 1.25) = 1.25
	#   640x360   @ 125% DPI → 0.5
	if scale_res >= 1.0 and _use_dpi_floor():
		target = maxf(scale_res, _get_physical_scale()) * physical_scale_multiplier
	target *= base_scale

	scale_factor = clampf(target, MIN_SCALE, MAX_SCALE)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = scale_factor


## Recommended settings default for "100%" on this platform.
func recommended_base_scale() -> float:
	return 1.0


func _root_window() -> Window:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root


func _use_dpi_floor() -> bool:
	# macOS / mobile report window.size in backing / density pixels already.
	return not PlatformUtils.is_mobile() and not PlatformUtils.is_macos()


func _get_physical_scale() -> float:
	var screen := DisplayServer.window_get_current_screen()
	var os_scale := DisplayServer.screen_get_scale(screen)
	var dpi := float(DisplayServer.screen_get_dpi(screen))
	var dpi_scale := dpi / BASE_DPI if dpi > 0.0 else 1.0
	# screen_get_scale is often 1.0 on Windows / X11 — take the larger value.
	var scale := maxf(os_scale if os_scale > 0.0 else 1.0, dpi_scale)
	if OS.has_feature("web"):
		scale *= WEB_PHYSICAL_MULT
	return scale
