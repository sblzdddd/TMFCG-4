class_name RoomStatusController
extends Container
## Combat lobby orchestrator: leave button + room_changed refresh.

@onready var leave_button := %LeaveButton
@onready var status_label := %StatusLabel
@onready var code_label := %CodeLabel
@onready var code_copy_button := %CodeCopyButton
@onready var leave_confirm_dialog := %LeaveConfirmDialog


func _ready() -> void:
	leave_button.pressed.connect(_on_leave_pressed)
	code_copy_button.pressed.connect(_on_copy_code)
	leave_confirm_dialog.confirmed.connect(_on_leave_confirmed)
	RoomSession.room_changed.connect(_on_room_changed)
	_on_room_changed(RoomSession.current_room)


func _on_room_changed(room: RoomData) -> void:
	leave_button.disabled = room == null
	code_copy_button.disabled = room == null
	code_label.text = "房间码: %s" % room.code\
		if room != null else "未在房间中"
	if room != null:
		status_label.text = "%s (%d/%d)" % [room.name, room.member_count(), room.max_players]
	else:
		status_label.text = "未在房间中"


func _on_leave_pressed() -> void:
	if RoomSession.current_room == null:
		return
	if RoomSession.is_local_host():
		leave_confirm_dialog.dialog_text = "离开将解散房间，确定继续？"
	else:
		leave_confirm_dialog.dialog_text = "确定要离开当前房间吗？"
	leave_confirm_dialog.popup_centered()


func _on_leave_confirmed() -> void:
	RoomSession.leave_room()


func _on_copy_code() -> void:
	var room := RoomSession.current_room
	if room == null or room.code.is_empty():
		return
	DisplayServer.clipboard_set(room.code)
	Toast.push("已复制房间码 %s" % room.code)
