extends Node
## Loads / creates app settings under user://.

const SAVE_PATH := "user://tmfcg/settings.tres"

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


func _normalize() -> void:
	if data.server_address.strip_edges().is_empty():
		data.server_address = "127.0.0.1"
	data.server_port = clampi(data.server_port, 1, 65535)
	save()
