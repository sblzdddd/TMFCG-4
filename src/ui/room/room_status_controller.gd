class_name RoomStatusController
extends Container
## Combat lobby orchestrator: leave button + room_changed refresh.

@onready var leave_button := %LeaveButton
@onready var status_label := %StatusLabel
@onready var code_label := %CodeLabel


func _ready() -> void:
	if leave_button:
		leave_button.pressed.connect(_on_leave)
	RoomManager.room_changed.connect(_on_room_changed)
	_on_room_changed(RoomManager.current_room)


func _on_room_changed(room: RoomData) -> void:
	leave_button.disabled = room == null
	code_label.text = "房间码: %s" % room.code\
		if room != null else "未在房间中"
	status_label.text = "%s" % [room.name]\
		if room != null else "未在房间中"


func _on_leave() -> void:
	RoomManager.leave_room()
