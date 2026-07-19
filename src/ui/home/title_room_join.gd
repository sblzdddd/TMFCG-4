class_name TitleRoomJoin
extends Node
## Join panel: connect by IP + public room list.


@onready var address_edit: LabelLineEdit = %AddressEdit
@onready var port_edit: LabelLineEdit = %PortEdit
@onready var connect_ip_button: Button = %ConnectIp
@onready var public_rooms_list: UiCardList = %PublicRoomsList
@onready var join_room_button: Button = %JoinRoom

var _rooms_by_code: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	if connect_ip_button:
		connect_ip_button.pressed.connect(_on_connect_ip)
	if join_room_button:
		join_room_button.pressed.connect(_on_join_selected)
	if public_rooms_list:
		public_rooms_list.item_activated.connect(_on_room_activated)
	BusyBlocker.actions_enabled_changed.connect(_set_actions_enabled)
	_set_actions_enabled(not BusyBlocker.is_busy())
	RoomDiscovery.rooms_updated.connect(_on_rooms_discovered)
	RoomDiscovery.start_listening()


func _exit_tree() -> void:
	RoomDiscovery.stop_listening()


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
		# Toast.push("请输入主机地址")
		# return
		address = "127.0.0.1"
	if not BusyBlocker.begin("正在连接 %s:%d…" % [address, port]):
		return
	var err := RoomSession.join_room(address, port)
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
	var err := RoomSession.join_room(address, port)
	if err != OK:
		BusyBlocker.end("加入失败: %s" % error_string(err))


func _on_rooms_discovered(rooms: Array[Dictionary]) -> void:
	if public_rooms_list == null:
		return
	_rooms_by_code.clear()
	var items: Array[UiCardEntry] = []
	for entry: Dictionary in rooms:
		var code := str(entry.get("code", ""))
		if code.is_empty():
			continue
		_rooms_by_code[code] = entry
		items.append(UiCardEntry.new(
			code,
			str(entry.get("name", "Room")),
			"%s · %d/%d · %s:%d" % [
				code,
				int(entry.get("players", 0)),
				int(entry.get("max", 4)),
				str(entry.get("address", "")),
				int(entry.get("port", NetConst.GAME_PORT)),
			],
		))
	public_rooms_list.set_items(items)
