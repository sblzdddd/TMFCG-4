extends Node

## Boosts [member Window.content_scale_factor] on HiDPI displays so UI stays readable.
## Web is skipped — the HTML export already applies device pixel ratio to the canvas.

const REFERENCE_DPI := 96.0
const MIN_WINDOW_SIZE := Vector2i(800, 600)


func _ready() -> void:
	var window := get_window()
	window.min_size = MIN_WINDOW_SIZE
	window.content_scale_factor = _get_display_scale(window.current_screen)


static func _get_display_scale(screen: int) -> float:
	if OS.has_feature("web"):
		return 1.0

	var os_scale := DisplayServer.screen_get_scale(screen)
	if os_scale > 0.0:
		return os_scale

	var dpi := DisplayServer.screen_get_dpi(screen)
	if dpi > 0:
		return maxf(1.0, float(dpi) / REFERENCE_DPI)

	return 1.0
