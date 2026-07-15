class_name RoomStatusController
extends Container
## Combat lobby orchestrator: leave button + room_changed refresh.

@onready var leave_button := %LeaveButton
@onready var status_label := %StatusLabel


func _ready() -> void:
	if leave_button:
		leave_button.pressed.connect(_on_leave)
	RoomManager.room_changed.connect(_on_room_changed)
	_on_room_changed(RoomManager.current_room)


func _on_room_changed(room: RoomData) -> void:
	if leave_button:
		leave_button.disabled = room == null
	if status_label:
		if room == null:
			status_label.text = "未在房间中"
		else:
			status_label.text = "%s · %d/%d" % [room.name, room.member_count(), room.max_players]


func _on_leave() -> void:
	RoomManager.leave_room()
