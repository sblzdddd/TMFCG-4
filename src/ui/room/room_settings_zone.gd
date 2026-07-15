class_name RoomSettingsZone
extends VBoxContainer
## Host-editable room options (name, public, max players).

@export var name_edit: LineEdit
@export var public_toggle: CheckButton
@export var max_players_spin: SpinBox
@export var code_label: Label

var _loading := false


func _ready() -> void:
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)
	if public_toggle:
		public_toggle.toggled.connect(_on_public_toggled)
	if max_players_spin:
		max_players_spin.value_changed.connect(_on_max_changed)
	RoomManager.room_changed.connect(_on_room_changed)
	_on_room_changed(RoomManager.current_room)


func _on_room_changed(room: RoomData) -> void:
	_loading = true
	var is_host := RoomManager.is_local_host()
	if room == null:
		_loading = false
		return
	if code_label:
		code_label.text = "房间码: %s" % room.code
	if name_edit:
		name_edit.text = room.name
		name_edit.editable = is_host
	if public_toggle:
		public_toggle.button_pressed = room.is_public
		public_toggle.disabled = not is_host
	if max_players_spin:
		max_players_spin.value = room.max_players
		max_players_spin.editable = is_host
	_loading = false


func _on_name_submitted(text: String) -> void:
	_commit_name(text)


func _on_name_focus_exited() -> void:
	if name_edit:
		_commit_name(name_edit.text)


func _commit_name(text: String) -> void:
	if _loading or not RoomManager.is_local_host():
		return
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	RoomManager.update_options({"name": trimmed})


func _on_public_toggled(pressed: bool) -> void:
	if _loading or not RoomManager.is_local_host():
		return
	RoomManager.update_options({"is_public": pressed})


func _on_max_changed(value: float) -> void:
	if _loading or not RoomManager.is_local_host():
		return
	RoomManager.update_options({"max_players": int(value)})
