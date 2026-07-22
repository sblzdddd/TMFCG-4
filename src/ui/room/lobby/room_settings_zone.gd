class_name RoomSettingsZone
extends Container
## Host-editable room options (name, public, max players).

@onready var name_edit := %NameEdit
@onready var public_toggle := %PublicToggle
@onready var max_players_spin := %MaxPlayers
@onready var turn_countdown_spin := %TurnCountdown
@onready var game_settings_toggle := %GameSettingsToggle
@onready var game_settings_root := %GameSettingsRoot
@onready var game_settings_layout := %GameSettingsLayout

var _loading := false
var _tween: Tween

func _ready() -> void:
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_on_name_focus_exited)
	public_toggle.toggled.connect(_on_public_toggled)
	max_players_spin.value_changed.connect(_on_max_changed)
	if turn_countdown_spin:
		turn_countdown_spin.value_changed.connect(_on_turn_countdown_changed)
	game_settings_toggle.toggled.connect(toggle_game_settings)

	RoomSession.room_changed.connect(_on_room_changed)
	_on_room_changed(RoomSession.current_room)

func toggle_game_settings(on: bool) -> void:
	_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(game_settings_layout, "modulate:a", 1 if on else 0, 0.5)
	_tween.parallel().tween_property(game_settings_root, "anchor_right", 1.0 if on else -0.2, 0.5)
	_tween.parallel().tween_property(game_settings_root, "anchor_left", 0.0 if on else -0.2, 0.5)

func _on_room_changed(room: RoomData) -> void:
	_loading = true
	var is_host := RoomSession.is_local_host()
	if room == null:
		_loading = false
		return
	name_edit.set_text_content(room.name)
	name_edit.visible = is_host
	public_toggle.button_pressed = room.is_public
	public_toggle.visible = is_host
	max_players_spin.value = room.max_players
	max_players_spin.visible = is_host
	if turn_countdown_spin:
		turn_countdown_spin.value = room.turn_countdown_sec
		turn_countdown_spin.visible = is_host
	_loading = false


func _on_name_submitted(text: String) -> void:
	_commit_name(text)


func _on_name_focus_exited() -> void:
	if name_edit:
		_commit_name(name_edit.text)


func _commit_name(text: String) -> void:
	if _loading or not RoomSession.is_local_host():
		return
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	RoomSession.update_options({"name": trimmed})


func _on_public_toggled(pressed: bool) -> void:
	if _loading or not RoomSession.is_local_host():
		return
	RoomSession.update_options({"is_public": pressed})


func _on_max_changed(value: float) -> void:
	if _loading or not RoomSession.is_local_host():
		return
	RoomSession.update_options({"max_players": int(value)})


func _on_turn_countdown_changed(value: float) -> void:
	if _loading or not RoomSession.is_local_host():
		return
	RoomSession.update_options({"turn_countdown_sec": int(value)})
