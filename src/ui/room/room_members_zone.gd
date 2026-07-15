class_name RoomMembersZone
extends VBoxContainer
## Room member cards with per-row kick (host only).

@export var members_list: CardList


func _ready() -> void:
	if members_list:
		members_list.action_pressed.connect(_on_action)
	RoomManager.room_changed.connect(_on_room_changed)
	RoomManager.member_kicked.connect(_on_member_kicked)
	RoomManager.kicked_from_room.connect(_on_kicked_from_room)
	RoomManager.member_left.connect(_on_member_left)
	RoomManager.left_room.connect(_on_left_room)
	RoomManager.room_dissolved.connect(_on_room_dissolved)
	_on_room_changed(RoomManager.current_room)


func _on_room_changed(room: RoomData) -> void:
	if members_list == null:
		return
	if room == null:
		members_list.clear_items()
		return
	var is_host := RoomManager.is_local_host()
	var items: Array[Dictionary] = []
	for member: RoomMember in room.get_members():
		var status := "在线" if member.is_online else "离线"
		var host_tag := " · 房主" if member.uid == room.host_uid else ""
		var can_kick := is_host and member.uid != room.host_uid
		var icon: Texture2D = null
		if not member.avatar_id.is_empty():
			icon = AvatarUtils.load_texture(member.avatar_id)
		items.append({
			"id": member.uid,
			"title": member.nickname,
			"subtitle": "%s%s" % [status, host_tag],
			"action_text": "踢出" if can_kick else "",
			"action_id": "kick" if can_kick else "",
			"icon": icon,
		})
	members_list.set_items(items)


func _on_action(uid: String, action_id: String) -> void:
	if action_id == "kick":
		RoomManager.kick_member(uid)


func _on_member_kicked(nickname: String) -> void:
	Toast.push("已踢出 %s" % nickname)


func _on_kicked_from_room(room_name: String) -> void:
	var name := room_name if not room_name.is_empty() else "房间"
	Toast.push("你已被踢出 %s" % name)


func _on_member_left(nickname: String) -> void:
	Toast.push("%s 离开了房间" % nickname)


func _on_left_room(room_name: String, was_host: bool) -> void:
	var name := room_name if not room_name.is_empty() else "房间"
	if was_host:
		Toast.push("已解散房间 %s" % name)
	else:
		Toast.push("已离开房间 %s" % name)


func _on_room_dissolved(room_name: String) -> void:
	var name := room_name if not room_name.is_empty() else "房间"
	Toast.push("房间 %s 已解散" % name)
