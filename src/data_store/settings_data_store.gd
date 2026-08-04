extends Node
## Loads / creates app settings under user://.

const SAVE_PATH := "user://tmfcg/settings.tres"
const DEBUG_SERVER_ADDRESS := "127.0.0.1"
const RELEASE_SERVER_ADDRESS := "rsjbd.sblzd.cn"
const MIN_WINDOW_SIZE := Vector2i(640, 360)
const DEFAULT_WINDOW_SIZE := Vector2i(1280, 720)
const MIN_FPS := 30
const MAX_FPS := 240

signal data_changed(data: SettingsData)

var data: SettingsData


func _ready() -> void:
	load_or_create()
	# Re-apply next frame so macOS Retina screen_get_scale is reliable.
	if PlatformUtils.is_macos():
		_apply_display.call_deferred()


func load_or_create() -> SettingsData:
	if FileAccess.file_exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SettingsData
		if loaded != null:
			data = loaded
			_normalize()
			return data
	data = SettingsData.new()
	data.server_address = _default_server_address()
	data.ui_base_scale = UiScale.recommended_base_scale()
	_apply_ui_scale()
	_apply_display()
	save()
	return data


func save() -> Error:
	if data == null:
		return ERR_INVALID_DATA
	ResourceFsUtils.ensure_directories()
	var root := ProjectSettings.globalize_path("user://tmfcg/")
	if not DirAccess.dir_exists_absolute(root):
		DirAccess.make_dir_recursive_absolute(root)
	return ResourceFsUtils.save_resource(data, SAVE_PATH)


func set_server_address(address: String) -> void:
	if data == null:
		return
	var trimmed := address.strip_edges()
	if data.server_address == trimmed:
		return
	data.server_address = trimmed
	save()
	data_changed.emit(data)


func set_server_port(port: int) -> void:
	if data == null:
		return
	var clamped := clampi(port, 1, 65535)
	if data.server_port == clamped:
		return
	data.server_port = clamped
	save()
	data_changed.emit(data)


func set_ui_base_scale(scale: float) -> void:
	if data == null:
		return
	var clamped := clampf(scale, UiScale.MIN_SCALE, UiScale.MAX_SCALE)
	if is_equal_approx(data.ui_base_scale, clamped):
		return
	data.ui_base_scale = clamped
	UiScale.base_scale = clamped
	save()
	data_changed.emit(data)


func set_window_mode(mode: int) -> void:
	if data == null:
		return
	var clamped := clampi(mode, SettingsData.WINDOW_MODE_WINDOWED, SettingsData.WINDOW_MODE_EXCLUSIVE)
	if data.window_mode == clamped:
		return
	data.window_mode = clamped
	_apply_display()
	save()
	data_changed.emit(data)


func set_window_resolution(size: Vector2i) -> void:
	if data == null:
		return
	var clamped := _clamp_window_size(size)
	if data.window_width == clamped.x and data.window_height == clamped.y:
		return
	data.window_width = clamped.x
	data.window_height = clamped.y
	_apply_display()
	save()
	data_changed.emit(data)


func set_max_fps(fps: int) -> void:
	if data == null:
		return
	var clamped := _clamp_fps(fps)
	if data.max_fps == clamped:
		return
	data.max_fps = clamped
	_apply_display()
	save()
	data_changed.emit(data)


func reset_to_defaults() -> void:
	data = SettingsData.new()
	data.server_address = _default_server_address()
	data.ui_base_scale = UiScale.recommended_base_scale()
	_apply_ui_scale()
	_apply_display()
	save()
	data_changed.emit(data)


func window_mode_to_display_server(mode: int) -> DisplayServer.WindowMode:
	match clampi(mode, SettingsData.WINDOW_MODE_WINDOWED, SettingsData.WINDOW_MODE_EXCLUSIVE):
		SettingsData.WINDOW_MODE_BORDERLESS:
			return DisplayServer.WINDOW_MODE_FULLSCREEN
		SettingsData.WINDOW_MODE_EXCLUSIVE:
			return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		_:
			return DisplayServer.WINDOW_MODE_WINDOWED


func display_server_to_window_mode(mode: DisplayServer.WindowMode) -> int:
	match mode:
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return SettingsData.WINDOW_MODE_BORDERLESS
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return SettingsData.WINDOW_MODE_EXCLUSIVE
		_:
			return SettingsData.WINDOW_MODE_WINDOWED


func _default_server_address() -> String:
	return DEBUG_SERVER_ADDRESS if OS.has_feature("editor") else RELEASE_SERVER_ADDRESS


func _apply_ui_scale() -> void:
	if data == null:
		return
	UiScale.base_scale = data.ui_base_scale


func supports_window_controls() -> bool:
	if PlatformUtils.is_mobile() or PlatformUtils.is_web():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return true


func _apply_display() -> void:
	if data == null:
		return
	Engine.max_fps = data.max_fps
	if not supports_window_controls():
		return
	var logical := Vector2i(data.window_width, data.window_height)
	var ds_mode := window_mode_to_display_server(data.window_mode)
	# Exclusive fullscreen uses the window size as the target monitor mode
	# (real pixel modes) — do not apply Retina scale there.
	if ds_mode == DisplayServer.WINDOW_MODE_WINDOWED \
			or ds_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := logical
		if ds_mode == DisplayServer.WINDOW_MODE_WINDOWED:
			size = _to_display_window_size(logical)
		DisplayServer.window_set_size(size)
	DisplayServer.window_set_mode(ds_mode)


## Convert a logical (settings) resolution to DisplayServer window pixels.
## On macOS Retina, Godot sizes are backing pixels — without multiplying by
## screen_get_scale(), 1280x720 becomes a ~640x360-point window (1/4 area).
func _to_display_window_size(logical: Vector2i) -> Vector2i:
	if not PlatformUtils.is_macos():
		return logical
	var screen := DisplayServer.window_get_current_screen()
	var scale := DisplayServer.screen_get_scale(screen)
	if scale <= 1.0:
		return logical
	return Vector2i(
		maxi(int(round(float(logical.x) * scale)), MIN_WINDOW_SIZE.x),
		maxi(int(round(float(logical.y) * scale)), MIN_WINDOW_SIZE.y),
	)


func _clamp_window_size(size: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(size.x, MIN_WINDOW_SIZE.x),
		maxi(size.y, MIN_WINDOW_SIZE.y),
	)


func _clamp_fps(fps: int) -> int:
	if fps <= 0:
		return 0
	return clampi(fps, MIN_FPS, MAX_FPS)


func _normalize() -> void:
	if data.server_address.strip_edges().is_empty():
		data.server_address = _default_server_address()
	data.server_port = clampi(data.server_port, 1, 65535)
	data.ui_base_scale = clampf(data.ui_base_scale, UiScale.MIN_SCALE, UiScale.MAX_SCALE)
	data.window_mode = clampi(
		data.window_mode,
		SettingsData.WINDOW_MODE_WINDOWED,
		SettingsData.WINDOW_MODE_EXCLUSIVE,
	)
	var size := _clamp_window_size(Vector2i(data.window_width, data.window_height))
	data.window_width = size.x
	data.window_height = size.y
	data.max_fps = _clamp_fps(data.max_fps)
	_apply_ui_scale()
	_apply_display()
	save()
