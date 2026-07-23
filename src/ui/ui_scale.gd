extends Node

## Smart global UI scaler.
## Small screens: shrink by resolution so the UI still fits.
## Large screens: grow by resolution so the UI scales up with the window.
## HiDPI (Windows / X11): physical (DPI / OS) scale is a floor so design-size
## windows still bump up.
## macOS / mobile: window size is already in physical / density pixels —
## skip the DPI floor to avoid double-counting Retina / device scale.

const BASE_DPI := 96.0
const DEFAULT_BASE_SIZE := Vector2(1152.0, 648.0)
const MIN_SCALE := 0.5
const MAX_SCALE := 3.0
## Extra physical-scale factor on desktop Web (browser DPI / devicePixelRatio quirks).
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
## Multiplier on large-screen scale only. Small screens, macOS, and mobile ignore it.
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
	# Re-evaluate when focus returns (e.g. window moved to another monitor).
	# macOS often fires this before/while nodes are detached — guard the tree.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree():
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

	# Small window: must shrink to fit.
	# macOS / mobile: fit by resolution only. Window size is already in
	# physical / density pixels; applying screen_get_scale / DPI as a floor
	# double-counts (Retina ~2x) and makes 100% feel twice as large.
	# Windows / X11 large / design-size window: grow with resolution, with DPI
	# as a floor so hiDPI still scales up when the window is only about
	# design-sized.
	#   2560x1440 @ 125% DPI, base 1280x720 → max(2.0, 1.25) = 2.0
	#   1280x720  @ 125% DPI                 → max(1.0, 1.25) = 1.25
	#   640x360   @ 125% DPI                 → 0.5
	var target: float
	if scale_res < 1.0 or _uses_physical_pixel_window_size():
		target = scale_res
	else:
		var scale_phys := _get_physical_scale()
		target = maxf(scale_res, scale_phys) * physical_scale_multiplier
	target *= base_scale

	scale_factor = clampf(target, MIN_SCALE, MAX_SCALE)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = scale_factor


## Recommended settings default for "100%" on this platform.
## Mobile / macOS keep 1.0 — adaptive resolution scaling handles density.
func recommended_base_scale() -> float:
	return 1.0


func _root_window() -> Window:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root


func _uses_physical_pixel_window_size() -> bool:
	# Godot reports window.size in backing pixels on these platforms, so OS /
	# DPI scale is already baked into the size used for scale_res.
	return PlatformUtils.is_mobile() or PlatformUtils.is_macos()


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
	# screen_get_scale is often 1.0 on Windows / X11, so take the larger of the
	# two. Not used on macOS / mobile (see _uses_physical_pixel_window_size).
	var scale := maxf(os_scale if os_scale > 0.0 else 1.0, dpi_scale)
	if OS.has_feature("web"):
		scale *= WEB_PHYSICAL_MULT
	return scale
