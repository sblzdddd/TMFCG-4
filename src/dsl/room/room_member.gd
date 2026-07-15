class_name RoomMember
extends RefCounted

var uid: String = ""
var nickname: String = ""
var avatar_id: String = ""
var peer_id: int = 0
var is_online: bool = true


func _init(
	p_uid: String = "",
	p_nickname: String = "",
	p_avatar_id: String = "",
	p_peer_id: int = 0,
	p_is_online: bool = true,
) -> void:
	uid = p_uid
	nickname = p_nickname
	avatar_id = p_avatar_id
	peer_id = p_peer_id
	is_online = p_is_online


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"nickname": nickname,
		"avatar_id": avatar_id,
		"peer_id": peer_id,
		"is_online": is_online,
	}


static func from_dict(d: Dictionary) -> RoomMember:
	return RoomMember.new(
		str(d.get("uid", "")),
		str(d.get("nickname", "")),
		str(d.get("avatar_id", "")),
		int(d.get("peer_id", 0)),
		bool(d.get("is_online", true)),
	)


static func from_local(peer_id_value: int) -> RoomMember:
	var data: PlayerData = PlayerDataStore.data
	var profile := PlayerDataStore.get_profile()
	var avatar := ""
	if profile.avatar_id != null:
		avatar = str(profile.avatar_id)
	return RoomMember.new(
		data.uid if data else "",
		profile.nickname,
		avatar,
		peer_id_value,
		true,
	)
