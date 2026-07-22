class_name TitleRoomCreate
extends Node
## Start panel: random match / create public / create private (lobby only).


@onready var random_match_button: Button = %RandomMatch
@onready var create_public_button: Button = %CreatePublic
@onready var create_private_button: Button = %CreatePrivate
@onready var max_players_edit: DraggerSpinBox = %MaxPlayers


func _ready() -> void:
	if random_match_button:
		random_match_button.pressed.connect(_on_random_match)
	if create_public_button:
		create_public_button.pressed.connect(_on_create_public)
	if create_private_button:
		create_private_button.pressed.connect(_on_create_private)
	BusyBlocker.actions_enabled_changed.connect(_set_actions_enabled)
	_set_actions_enabled(not BusyBlocker.is_busy())


func _max_players() -> int:
	return int(max_players_edit.value)


func _set_actions_enabled(enabled: bool) -> void:
	var mouse := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button: Button in [random_match_button, create_public_button, create_private_button]:
		if button:
			button.disabled = not enabled
	if max_players_edit:
		max_players_edit.editable = enabled
		max_players_edit.mouse_filter = mouse


func _ensure_central() -> bool:
	if NetworkModeService.is_central_connected():
		return true
	BusyBlocker.show_hint("正在连接服务器…")
	return await NetworkModeService.ensure_central_async()


func _on_random_match() -> void:
	if not BusyBlocker.begin("正在搜索公开房间…"):
		return
	if not await _ensure_central():
		BusyBlocker.end("无法连接服务器")
		return
	await _random_match_online()


func _random_match_online() -> void:
	RoomSession.online_client.request_public_rooms()
	var rooms: Array = await RoomSession.online_rooms_received
	for entry in rooms:
		if not entry is Dictionary:
			continue
		if (
			int(entry.get("players", 0)) < int(entry.get("max", 4))
			and int(entry.get("max", 4)) == _max_players()
		):
			BusyBlocker.show_hint("正在加入房间 %s…" % str(entry.get("code", "")))
			var join_err := RoomSession.join_room_code(str(entry.get("code", "")))
			if join_err != OK:
				BusyBlocker.end("加入失败: %s" % error_string(join_err))
			return
	BusyBlocker.show_hint("未找到房间，正在创建新房间…")
	var create_err := RoomSession.create_room(true, _max_players())
	if create_err != OK:
		BusyBlocker.end("创建失败: %s" % error_string(create_err))


func _on_create_public() -> void:
	if not BusyBlocker.begin("正在创建公开房间…"):
		return
	if not await _ensure_central():
		BusyBlocker.end("无法连接服务器")
		return
	var err := RoomSession.create_room(true, _max_players())
	if err != OK:
		BusyBlocker.end("创建失败: %s" % error_string(err))


func _on_create_private() -> void:
	if not BusyBlocker.begin("正在创建私密房间…"):
		return
	if not await _ensure_central():
		BusyBlocker.end("无法连接服务器")
		return
	var err := RoomSession.create_room(false, _max_players())
	if err != OK:
		BusyBlocker.end("创建失败: %s" % error_string(err))
