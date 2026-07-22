class_name TitleRoomJoin
extends Node
## Join panel: room code + public room list (lobby only).


@onready var address_edit: LabelLineEdit = %AddressEdit
@onready var connect_ip_button: Button = %ConnectIp
@onready var public_rooms_list: UiCardList = %PublicRoomsList
@onready var join_room_button: Button = %JoinRoom

var _rooms_by_code: Dictionary[String, Dictionary] = {}
var _refresh_timer: Timer


func _ready() -> void:
	if connect_ip_button:
		connect_ip_button.pressed.connect(_on_join_by_code)
	if join_room_button:
		join_room_button.pressed.connect(_on_join_selected)
	if public_rooms_list:
		public_rooms_list.item_activated.connect(_on_room_activated)
	BusyBlocker.actions_enabled_changed.connect(_set_actions_enabled)
	_set_actions_enabled(not BusyBlocker.is_busy())
	RoomSession.online_rooms_received.connect(_on_online_rooms)
	NetworkModeService.mode_applied.connect(_on_mode_applied)
	_refresh_public_list()


func _exit_tree() -> void:
	if _refresh_timer != null:
		_refresh_timer.stop()


func _on_mode_applied(online: bool) -> void:
	if online:
		_refresh_public_list()
	elif _refresh_timer != null:
		_refresh_timer.stop()


func _refresh_public_list() -> void:
	if not NetworkModeService.is_central_connected():
		if _refresh_timer != null:
			_refresh_timer.stop()
		return
	_ensure_refresh_timer()
	RoomSession.online_client.request_public_rooms()


func _ensure_refresh_timer() -> void:
	if _refresh_timer != null:
		_refresh_timer.start()
		return
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 2.0
	_refresh_timer.timeout.connect(func() -> void:
		if NetworkModeService.is_central_connected():
			RoomSession.online_client.request_public_rooms()
	)
	add_child(_refresh_timer)
	_refresh_timer.start()


func _set_actions_enabled(enabled: bool) -> void:
	var mouse := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button: Button in [connect_ip_button, join_room_button]:
		if button:
			button.disabled = not enabled
	if address_edit:
		address_edit.set("editable", enabled)
		address_edit.mouse_filter = mouse
	if public_rooms_list:
		public_rooms_list.mouse_filter = mouse


func _ensure_central() -> bool:
	if NetworkModeService.is_central_connected():
		return true
	BusyBlocker.show_hint("正在连接服务器…")
	return await NetworkModeService.ensure_central_async()


func _on_join_by_code() -> void:
	if BusyBlocker.is_busy():
		return
	var code := ""
	if address_edit:
		code = str(address_edit.get("text")).strip_edges()
	if code.is_empty():
		Toast.push("请输入房间代码")
		return
	if not BusyBlocker.begin("正在加入房间 %s…" % code):
		return
	if not await _ensure_central():
		BusyBlocker.end("无法连接服务器")
		return
	var online_err := RoomSession.join_room_code(code)
	if online_err != OK:
		BusyBlocker.end("加入失败: %s" % error_string(online_err))


func _on_join_selected() -> void:
	if BusyBlocker.is_busy():
		return
	_join_code(public_rooms_list.get_selected_id() if public_rooms_list else "")


func _on_room_activated(code: String) -> void:
	if BusyBlocker.is_busy():
		return
	_join_code(code)


func _join_code(code: String) -> void:
	if code.is_empty() or not _rooms_by_code.has(code):
		Toast.push("请先选择一个公开房间")
		return
	if not BusyBlocker.begin("正在加入房间 %s…" % code):
		return
	if not await _ensure_central():
		BusyBlocker.end("无法连接服务器")
		return
	var online_err := RoomSession.join_room_code(code)
	if online_err != OK:
		BusyBlocker.end("加入失败: %s" % error_string(online_err))


func _on_online_rooms(rooms: Array) -> void:
	_apply_room_list(rooms)


func _apply_room_list(rooms: Array) -> void:
	if public_rooms_list == null:
		return
	_rooms_by_code.clear()
	var items: Array[UiCardEntry] = []
	for entry in rooms:
		if not entry is Dictionary:
			continue
		var code := str(entry.get("code", ""))
		if code.is_empty():
			continue
		_rooms_by_code[code] = entry
		var subtitle := "%s · %d/%d" % [
			code,
			int(entry.get("players", 0)),
			int(entry.get("max", 4)),
		]
		items.append(UiCardEntry.new(
			code,
			str(entry.get("name", "Room")),
			subtitle,
		))
	public_rooms_list.set_items(items)
