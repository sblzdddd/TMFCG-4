extends Node
## Loads / creates app settings under user://.

const SAVE_PATH := "user://tmfcg/settings.tres"
const DEBUG_SERVER_ADDRESS := "127.0.0.1"
const RELEASE_SERVER_ADDRESS := "rsjbd.sblzd.cn"

signal data_changed(data: SettingsData)

var data: SettingsData


func _ready() -> void:
	load_or_create()


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


func reset_to_defaults() -> void:
	data = SettingsData.new()
	data.server_address = _default_server_address()
	data.ui_base_scale = UiScale.recommended_base_scale()
	_apply_ui_scale()
	save()
	data_changed.emit(data)


func _default_server_address() -> String:
	return DEBUG_SERVER_ADDRESS if OS.has_feature("editor") else RELEASE_SERVER_ADDRESS


func _apply_ui_scale() -> void:
	if data == null:
		return
	UiScale.base_scale = data.ui_base_scale


func _normalize() -> void:
	if data.server_address.strip_edges().is_empty():
		data.server_address = _default_server_address()
	data.server_port = clampi(data.server_port, 1, 65535)
	data.ui_base_scale = clampf(data.ui_base_scale, UiScale.MIN_SCALE, UiScale.MAX_SCALE)
	_apply_ui_scale()
	save()
