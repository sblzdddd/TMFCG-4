extends GridContainer
class_name DisplaySettingsEditor
## Settings panel: display mode, resolution, UI scale, and max FPS.

const SCALE_OPTIONS: Array[Dictionary] = [
	{"label": "50%", "value": 0.5},
	{"label": "60%", "value": 0.6},
	{"label": "75%", "value": 0.75},
	{"label": "80%", "value": 0.8},
	{"label": "90%", "value": 0.9},
	{"label": "100%", "value": 1.0},
	{"label": "110%", "value": 1.1},
	{"label": "125%", "value": 1.25},
	{"label": "130%", "value": 1.3},
	{"label": "150%", "value": 1.5},
	{"label": "175%", "value": 1.75},
	{"label": "200%", "value": 2.0},
]

const RESOLUTION_CANDIDATES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

@export var _scale_option: OptionButton
@export var _resolution_option: OptionButton
@export var _display_options: OptionButton
@export var _fps_edit: DraggerSpinBox

var _loading := false
var _resolutions: Array[Vector2i] = []


func _ready() -> void:
	_populate_scale_options()
	_populate_resolution_options()
	if _scale_option:
		_scale_option.item_selected.connect(_on_scale_selected)
	if _display_options:
		_display_options.item_selected.connect(_on_display_selected)
	if _resolution_option:
		_resolution_option.item_selected.connect(_on_resolution_selected)
	if _fps_edit:
		_fps_edit.min_value = SettingsDataStore.MIN_FPS
		_fps_edit.max_value = SettingsDataStore.MAX_FPS
		_fps_edit.step = 30.0
		_fps_edit.value_changed.connect(_on_fps_changed)
	_configure_platform_controls()
	SettingsDataStore.data_changed.connect(_on_store_changed)
	_apply_data(SettingsDataStore.data)


func _configure_platform_controls() -> void:
	if SettingsDataStore.supports_window_controls():
		return
	if _display_options:
		_display_options.disabled = true
	if _resolution_option:
		_resolution_option.disabled = true


func _populate_scale_options() -> void:
	if _scale_option == null:
		return
	_scale_option.clear()
	for i in SCALE_OPTIONS.size():
		var option: Dictionary = SCALE_OPTIONS[i]
		_scale_option.add_item(str(option["label"]), i)


func _populate_resolution_options() -> void:
	if _resolution_option == null:
		return
	_resolutions.clear()
	_resolution_option.clear()
	var screen := _usable_screen_size()
	var saved := Vector2i.ZERO
	if SettingsDataStore.data != null:
		saved = Vector2i(SettingsDataStore.data.window_width, SettingsDataStore.data.window_height)
	for size in RESOLUTION_CANDIDATES:
		if size.x > screen.x or size.y > screen.y:
			continue
		_add_resolution(size)
	if saved != Vector2i.ZERO and not _resolutions.has(saved):
		_add_resolution(saved)
	if _resolutions.is_empty():
		_add_resolution(SettingsDataStore.DEFAULT_WINDOW_SIZE)


func _add_resolution(size: Vector2i) -> void:
	_resolutions.append(size)
	_resolution_option.add_item("%dx%d" % [size.x, size.y], _resolutions.size() - 1)


func _usable_screen_size() -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	var size := DisplayServer.screen_get_usable_rect(screen).size
	if size.x <= 0 or size.y <= 0:
		size = DisplayServer.screen_get_size(screen)
	if size.x <= 0 or size.y <= 0:
		return Vector2i(3840, 2160)
	# Settings resolutions are logical; macOS screen metrics are backing pixels.
	if PlatformUtils.is_macos():
		var screen_scale := DisplayServer.screen_get_scale(screen)
		if screen_scale > 1.0:
			size = Vector2i(
				maxi(int(floor(float(size.x) / screen_scale)), 1),
				maxi(int(floor(float(size.y) / screen_scale)), 1),
			)
	return size


func _on_scale_selected(index: int) -> void:
	if _loading or index < 0 or index >= SCALE_OPTIONS.size():
		return
	SettingsDataStore.set_ui_base_scale(float(SCALE_OPTIONS[index]["value"]))


func _on_display_selected(index: int) -> void:
	if _loading:
		return
	SettingsDataStore.set_window_mode(index)


func _on_resolution_selected(index: int) -> void:
	if _loading or index < 0 or index >= _resolutions.size():
		return
	SettingsDataStore.set_window_resolution(_resolutions[index])


func _on_fps_changed(value: float) -> void:
	if _loading:
		return
	SettingsDataStore.set_max_fps(int(round(value)))


func _on_store_changed(data: SettingsData) -> void:
	_apply_data(data)


func _apply_data(data: SettingsData) -> void:
	if data == null:
		return
	_loading = true
	if _scale_option:
		_scale_option.select(_nearest_scale_index(data.ui_base_scale))
	if _display_options:
		_display_options.select(clampi(
			data.window_mode,
			SettingsData.WINDOW_MODE_WINDOWED,
			SettingsData.WINDOW_MODE_EXCLUSIVE,
		))
	if _resolution_option:
		var res_index := _resolution_index(Vector2i(data.window_width, data.window_height))
		if res_index < 0:
			_populate_resolution_options()
			res_index = _resolution_index(Vector2i(data.window_width, data.window_height))
		if res_index >= 0:
			_resolution_option.select(res_index)
		_resolution_option.disabled = (
			not SettingsDataStore.supports_window_controls()
			or data.window_mode == SettingsData.WINDOW_MODE_BORDERLESS
		)
	if _fps_edit:
		_fps_edit.value = float(data.max_fps)
	_loading = false


func _resolution_index(size: Vector2i) -> int:
	for i in _resolutions.size():
		if _resolutions[i] == size:
			return i
	return -1


func _nearest_scale_index(scale: float) -> int:
	var best_index := 5
	var best_dist := INF
	for i in SCALE_OPTIONS.size():
		var dist := absf(float(SCALE_OPTIONS[i]["value"]) - scale)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index
