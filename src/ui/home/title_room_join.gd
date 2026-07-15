class_name TitleRoomJoin
extends Node
## Join panel: connect by IP + public room list.


@onready var address_edit: LabelLineEdit = %AddressEdit
@onready var port_edit: LabelLineEdit = %PortEdit
@onready var connect_ip_button: Button = %ConnectIp
@onready var public_rooms_list: CardList = %PublicRoomsList
@onready var join_room_button: Button = %JoinRoom

var _rooms_by_code: Dictionary[String, Dictionary] = {}
var _discover_toast_id := -1
var _discover_elapsed := 0.0
var _announced_rooms := false


func _ready() -> void:
	if connect_ip_button:
		connect_ip_button.pressed.connect(_on_connect_ip)
	if join_room_button:
		join_room_button.pressed.connect(_on_join_selected)
	if public_rooms_list:
		public_rooms_list.item_activated.connect(_on_room_activated)
	BusyBlocker.actions_enabled_changed.connect(_set_actions_enabled)
	_set_actions_enabled(not BusyBlocker.is_busy())
	RoomManager.rooms_discovered.connect(_on_rooms_discovered)
	RoomManager.start_discovery_listen()
	_discover_toast_id = Toast.push(
		"正在搜索局域网房间… %.1fs" % NetConst.RANDOM_MATCH_WAIT_SEC,
		0.0,
	)
	set_process(true)


func _exit_tree() -> void:
	RoomManager.stop_discovery_listen()
	if _discover_toast_id >= 0:
		Toast.dismiss(_discover_toast_id)
		_discover_toast_id = -1


func _process(delta: float) -> void:
	if _discover_toast_id < 0:
		return
	_discover_elapsed += delta
	var left := NetConst.RANDOM_MATCH_WAIT_SEC - _discover_elapsed
	if left > 0.0:
		Toast.update(_discover_toast_id, "正在搜索局域网房间… %.1fs" % left)
	else:
		Toast.dismiss(_discover_toast_id)
		_discover_toast_id = -1
		set_process(false)


func _set_actions_enabled(enabled: bool) -> void:
	var mouse := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button: Button in [connect_ip_button, join_room_button]:
		if button:
			button.disabled = not enabled
	if address_edit:
		address_edit.set("editable", enabled)
		address_edit.mouse_filter = mouse
	if port_edit:
		port_edit.set("editable", enabled)
		port_edit.mouse_filter = mouse
	if public_rooms_list:
		public_rooms_list.mouse_filter = mouse


func _on_connect_ip() -> void:
	if BusyBlocker.is_busy():
		return
	var address: String = ""
	if address_edit:
		address = str(address_edit.get("text")).strip_edges()
	var port: int = NetConst.GAME_PORT
	if port_edit and not str(port_edit.get("text")).strip_edges().is_empty():
		port = int(str(port_edit.get("text")).strip_edges())
	if address.is_empty():
		Toast.push("请输入主机地址")
		return
	if not BusyBlocker.begin("正在连接 %s:%d…" % [address, port]):
		return
	var err := RoomManager.join_room(address, port)
	if err != OK:
		BusyBlocker.end("连接失败: %s" % error_string(err))


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
	var entry: Dictionary = _rooms_by_code[code]
	var address := str(entry.get("address", ""))
	var port := int(entry.get("port", NetConst.GAME_PORT))
	if not BusyBlocker.begin("正在加入房间 %s…" % code):
		return
	var err := RoomManager.join_room(address, port)
	if err != OK:
		BusyBlocker.end("加入失败: %s" % error_string(err))


func _on_rooms_discovered(rooms: Array[Dictionary]) -> void:
	if public_rooms_list == null:
		return
	_rooms_by_code.clear()
	var items: Array[Dictionary] = []
	for entry: Dictionary in rooms:
		var code := str(entry.get("code", ""))
		if code.is_empty():
			continue
		_rooms_by_code[code] = entry
		items.append({
			"id": code,
			"title": str(entry.get("name", "Room")),
			"subtitle": "%s · %d/%d · %s:%d" % [
				code,
				int(entry.get("players", 0)),
				int(entry.get("max", 4)),
				str(entry.get("address", "")),
				int(entry.get("port", NetConst.GAME_PORT)),
			],
		})
	public_rooms_list.set_items(items)
	if items.is_empty() or _announced_rooms:
		return
	_announced_rooms = true
	var msg := "已发现 %d 个公开房间" % items.size()
	if _discover_toast_id >= 0:
		Toast.update(_discover_toast_id, msg, Toast.DEFAULT_DURATION)
		_discover_toast_id = -1
		set_process(false)
	else:
		Toast.push(msg)
