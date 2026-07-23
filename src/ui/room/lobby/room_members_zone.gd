class_name RoomMembersZone
extends VBoxContainer
## Room member UI cards with per-row kick (host only).

@onready var members_list: UiCardList = %MembersList

func _ready() -> void:
	if members_list:
		members_list.action_pressed.connect(_on_action)
	RoomSession.room_changed.connect(_on_room_changed)
	RoomSession.member_kicked.connect(_on_member_kicked)
	RoomSession.kicked_from_room.connect(_on_kicked_from_room)
	RoomSession.member_left.connect(_on_member_left)
	RoomSession.left_room.connect(_on_left_room)
	RoomSession.room_dissolved.connect(_on_room_dissolved)
	_on_room_changed(RoomSession.current_room)


func _on_room_changed(room: RoomData) -> void:
	if room == null:
		members_list.clear_items()
		return
	var is_host := RoomSession.is_local_host()
	var items: Array[UiCardEntry] = []
	for member: RoomMember in room.get_members():
		var status := "在线" if member.is_online else "离线"
		var host_tag := " · 房主" if member.uid == room.host_uid else ""
		var can_kick := is_host and member.uid != room.host_uid
		var icon: Texture2D = null
		if not member.avatar_id.is_empty():
			icon = AvatarUtils.load_texture(member.avatar_id)
		items.append(UiCardEntry.new(
			member.uid,
			member.nickname,
			"%s%s" % [status, host_tag],
			"踢出" if can_kick else "",
			"kick" if can_kick else "",
			icon,
		))
	members_list.set_items(items)


func _on_action(uid: String, action_id: String) -> void:
	if action_id == "kick":
		RoomSession.kick_member(uid)


func _on_member_kicked(nickname: String) -> void:
	Toast.push("已踢出 %s" % nickname)


func _on_kicked_from_room(room_name: String) -> void:
	Toast.push("你已被踢出 %s" % room_name if not room_name.is_empty() else "房间")


func _on_member_left(nickname: String) -> void:
	Toast.push("%s 离开了房间" % nickname)


func _on_left_room(room_name: String, was_host: bool) -> void:
	if was_host:
		Toast.push("已解散房间 %s" % room_name)
	else:
		Toast.push("已离开房间 %s" % room_name)


func _on_room_dissolved(room_name: String) -> void:
	Toast.push("房间 %s 已解散" % room_name)
