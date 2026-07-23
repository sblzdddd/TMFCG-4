class_name RoomSettingsZone
extends VBoxContainer
## Host-editable room options (name, public, max players, turn countdown).
## Lives in the shared game-settings popup. Non-hosts see a read-only turn-countdown label.

const OPTIONS_REPORT_THROTTLE_SEC := 0.2

@onready var name_edit := %NameEdit
@onready var public_toggle := %PublicToggle
@onready var max_players_spin := %MaxPlayers
@onready var turn_countdown_spin := %TurnCountdown
@onready var turn_countdown_label: Label = %TurnCountdownLabel
@onready var game_settings_toggle := %GameSettingsToggle
@onready var game_settings_root := %GameSettingsRoot
@onready var game_settings_layout := %GameSettingsLayout

var _loading := false
var _tween: Tween
## Host intent not yet confirmed by a matching room snapshot.
var _pending_options: Dictionary = {}
var _options_report_token := 0


func _ready() -> void:
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_on_name_focus_exited)
	public_toggle.toggled.connect(_on_public_toggled)
	max_players_spin.value_changed.connect(_on_max_changed)
	if turn_countdown_spin:
		turn_countdown_spin.value_changed.connect(_on_turn_countdown_changed)
	game_settings_toggle.toggled.connect(toggle_game_settings)

	RoomSession.room_changed.connect(_on_room_changed)
	RoomSession.match_changed.connect(func(_s) -> void: _on_room_changed(RoomSession.current_room))
	_on_room_changed(RoomSession.current_room)


func toggle_game_settings(on: bool) -> void:
	_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(game_settings_layout, "modulate:a", 1 if on else 0, 0.5)
	_tween.parallel().tween_property(game_settings_root, "anchor_right", 1.0 if on else -0.2, 0.5)
	_tween.parallel().tween_property(game_settings_root, "anchor_left", 0.0 if on else -0.2, 0.5)


func _on_room_changed(room: RoomData) -> void:
	_loading = true
	var is_host := RoomSession.is_local_host()
	var locked := RoomMatchLock.is_match_locked()
	if room == null:
		_pending_options.clear()
		_options_report_token += 1
		if turn_countdown_label:
			turn_countdown_label.visible = false
		_loading = false
		return
	_confirm_pending_from_room(room)
	if not _pending_options.has("name"):
		name_edit.set_text_content(room.name)
	name_edit.visible = is_host
	name_edit.editable = is_host and not locked
	if not _pending_options.has("is_public"):
		public_toggle.button_pressed = room.is_public
	public_toggle.visible = is_host
	public_toggle.disabled = locked
	if not _pending_options.has("max_players"):
		max_players_spin.value = room.max_players
	max_players_spin.visible = is_host
	max_players_spin.editable = not locked
	if turn_countdown_spin:
		if not _pending_options.has("turn_countdown_sec"):
			turn_countdown_spin.value = room.turn_countdown_sec
		turn_countdown_spin.visible = is_host
		turn_countdown_spin.editable = not locked
	if turn_countdown_label:
		turn_countdown_label.text = "回合倒计时: %d 秒" % room.turn_countdown_sec
		turn_countdown_label.visible = not is_host
	_loading = false


func _on_name_submitted(text: String) -> void:
	_commit_name(text)


func _on_name_focus_exited() -> void:
	if name_edit:
		_commit_name(name_edit.text)


func _commit_name(text: String) -> void:
	if _loading or not RoomSession.is_local_host() or RoomMatchLock.is_match_locked():
		return
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	_queue_options_update({"name": trimmed})


func _on_public_toggled(pressed: bool) -> void:
	if _loading or not RoomSession.is_local_host() or RoomMatchLock.is_match_locked():
		return
	_queue_options_update({"is_public": pressed})


func _on_max_changed(value: float) -> void:
	if _loading or not RoomSession.is_local_host() or RoomMatchLock.is_match_locked():
		return
	_queue_options_update({"max_players": int(value)})


func _on_turn_countdown_changed(value: float) -> void:
	if _loading or not RoomSession.is_local_host() or RoomMatchLock.is_match_locked():
		return
	_queue_options_update({"turn_countdown_sec": int(value)})


func _queue_options_update(patch: Dictionary) -> void:
	for key in patch.keys():
		_pending_options[key] = patch[key]
	_options_report_token += 1
	var token := _options_report_token
	get_tree().create_timer(OPTIONS_REPORT_THROTTLE_SEC).timeout.connect(
		func() -> void:
			if token != _options_report_token:
				return
			_flush_pending_options()
	)


func _flush_pending_options() -> void:
	if _pending_options.is_empty():
		return
	if not RoomSession.is_local_host() or RoomMatchLock.is_match_locked():
		_pending_options.clear()
		return
	RoomSession.update_options(_pending_options.duplicate())


func _confirm_pending_from_room(room: RoomData) -> void:
	if _pending_options.is_empty():
		return
	var confirmed: Array = []
	for key in _pending_options.keys():
		var desired: Variant = _pending_options[key]
		var actual: Variant = null
		match str(key):
			"name":
				actual = room.name
			"is_public":
				actual = room.is_public
			"max_players":
				actual = room.max_players
			"turn_countdown_sec":
				actual = room.turn_countdown_sec
			_:
				continue
		if desired == actual:
			confirmed.append(key)
	for key in confirmed:
		_pending_options.erase(key)
