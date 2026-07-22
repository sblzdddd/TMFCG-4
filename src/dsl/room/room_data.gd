class_name RoomData
extends Resource

@export var code: String = ""
@export var name: String = "Room"
@export var is_public: bool = false
@export var max_players: int = 4
## Seconds a player has to act each turn (UI bars + server force-pass timer).
## Host grace adds +10s on the authoritative MatchController timeout.
@export var turn_countdown_sec: int = 15
@export var host_uid: String = ""
## Array of Dictionary snapshots (uid, nickname, avatar_id, peer_id, is_online).
@export var members: Array = []
@export var deck: RoomDeckProfile = null


func member_count() -> int:
	return members.size()


func is_full() -> bool:
	return members.size() >= max_players


func get_members() -> Array[RoomMember]:
	var result: Array[RoomMember] = []
	for entry in members:
		if entry is Dictionary:
			result.append(RoomMember.from_dict(entry))
	return result


func find_member_uid(uid: String) -> int:
	for i in members.size():
		var entry: Variant = members[i]
		if entry is Dictionary and str(entry.get("uid", "")) == uid:
			return i
	return -1


func find_member_peer(peer_id: int) -> int:
	for i in members.size():
		var entry: Variant = members[i]
		if entry is Dictionary and int(entry.get("peer_id", 0)) == peer_id:
			return i
	return -1


func upsert_member(member: RoomMember) -> void:
	var idx := find_member_uid(member.uid)
	var snapshot := member.to_dict()
	if idx >= 0:
		members[idx] = snapshot
	else:
		members.append(snapshot)


func remove_member_uid(uid: String) -> bool:
	var idx := find_member_uid(uid)
	if idx < 0:
		return false
	members.remove_at(idx)
	return true


func set_member_online(uid: String, online: bool, new_peer_id: int = -1) -> bool:
	var idx := find_member_uid(uid)
	if idx < 0:
		return false
	var entry: Dictionary = (members[idx] as Dictionary).duplicate()
	entry["is_online"] = online
	if new_peer_id >= 0:
		entry["peer_id"] = new_peer_id
	members[idx] = entry
	return true


func ensure_deck() -> RoomDeckProfile:
	if deck == null:
		deck = RoomDeckProfile.new()
	return deck


func to_snapshot() -> Dictionary:
	return {
		"code": code,
		"name": name,
		"is_public": is_public,
		"max_players": max_players,
		"turn_countdown_sec": turn_countdown_sec,
		"host_uid": host_uid,
		"members": members.duplicate(true),
		"deck": deck.to_dict() if deck != null else {},
	}


static func from_snapshot(data: Dictionary) -> RoomData:
	var room := RoomData.new()
	room.code = str(data.get("code", ""))
	room.name = str(data.get("name", "Room"))
	room.is_public = bool(data.get("is_public", false))
	room.max_players = int(data.get("max_players", 4))
	room.turn_countdown_sec = clampi(int(data.get("turn_countdown_sec", 15)), 5, 45)
	room.host_uid = str(data.get("host_uid", ""))
	var raw_members: Variant = data.get("members", [])
	if raw_members is Array:
		room.members = (raw_members as Array).duplicate(true)
	var raw_deck: Variant = data.get("deck", {})
	if raw_deck is Dictionary:
		room.deck = RoomDeckProfile.from_dict(raw_deck as Dictionary)
	else:
		room.deck = RoomDeckProfile.new()
	return room


static func create_hosted(
	host_member: RoomMember,
	room_name: String,
	public: bool,
	max_players_value: int,
) -> RoomData:
	var room := RoomData.new()
	room.code = NetConst.generate_room_code()
	room.name = room_name
	room.is_public = public
	room.max_players = clampi(max_players_value, 2, 4)
	room.turn_countdown_sec = 15
	room.host_uid = host_member.uid
	room.members = [host_member.to_dict()]
	room.deck = RoomDeckProfile.create_default_builtin()
	return room
