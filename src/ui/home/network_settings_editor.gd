extends GridContainer
class_name NetworkSettingsEditor
## Settings panel: central dedicated-server address/port.
## Hidden while in a room so host cannot be hard-switched mid-session.

@export var _address_edit: LabelLineEdit
@export var _port_edit: LabelLineEdit

var _loading := false


func _ready() -> void:
	if _is_in_room_context():
		_hide_network_zone()
		return
	if _address_edit:
		_address_edit.text_submitted.connect(_on_address_submitted)
		_address_edit.focus_exited.connect(_on_address_focus_exited)
	if _port_edit:
		_port_edit.text_submitted.connect(_on_port_submitted)
		_port_edit.focus_exited.connect(_on_port_focus_exited)
	SettingsDataStore.data_changed.connect(_on_store_changed)
	_apply_data(SettingsDataStore.data)


func _is_in_room_context() -> bool:
	if RoomSession.current_room != null:
		return true
	var tree := get_tree()
	if tree == null:
		return false
	return RoomUtils.scene_path(tree) == NetConst.ROOM_SCENE


func _hide_network_zone() -> void:
	visible = false
	var title := get_parent().get_node_or_null("NetworkTitle") as CanvasItem
	if title:
		title.visible = false


func _on_address_submitted(new_text: String) -> void:
	_commit_address(new_text)


func _on_address_focus_exited() -> void:
	if _address_edit:
		_commit_address(str(_address_edit.get("text")))


func _on_port_submitted(new_text: String) -> void:
	_commit_port(new_text)


func _on_port_focus_exited() -> void:
	if _port_edit:
		_commit_port(str(_port_edit.get("text")))


func _commit_address(new_text: String) -> void:
	if _loading:
		return
	SettingsDataStore.set_server_address(new_text)
	NetworkModeService.apply_preferred_mode()


func _commit_port(new_text: String) -> void:
	if _loading:
		return
	var trimmed := new_text.strip_edges()
	if trimmed.is_empty() or not trimmed.is_valid_int():
		_apply_data(SettingsDataStore.data)
		return
	SettingsDataStore.set_server_port(int(trimmed))
	NetworkModeService.apply_preferred_mode()


func _on_store_changed(data: SettingsData) -> void:
	_apply_data(data)


func _apply_data(data: SettingsData) -> void:
	if data == null:
		return
	_loading = true
	if _address_edit and not _address_edit.has_focus():
		_address_edit.set_text_content(data.server_address)
	if _port_edit and not _port_edit.has_focus():
		_port_edit.set_text_content(str(data.server_port))
	_loading = false
