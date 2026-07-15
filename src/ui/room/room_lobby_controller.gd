class_name RoomLobbyController
extends Control
## Combat lobby orchestrator: leave button + room_changed refresh.

@export var leave_button: Button
@export var status_label: Label


func _ready() -> void:
	if leave_button:
		leave_button.pressed.connect(_on_leave)
	RoomManager.room_changed.connect(_on_room_changed)
	_on_room_changed(RoomManager.current_room)


func _on_room_changed(room: RoomData) -> void:
	if leave_button:
		leave_button.disabled = room == null
		leave_button.text = "解散房间" if RoomManager.is_local_host() else "离开房间"
	if status_label:
		if room == null:
			status_label.text = "未在房间中"
		else:
			status_label.text = "%s · %d/%d" % [room.name, room.member_count(), room.max_players]


func _on_leave() -> void:
	RoomManager.leave_room()
