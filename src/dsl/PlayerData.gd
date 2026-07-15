class_name PlayerData
extends Resource

@export var uid: String = "user-0"
@export var name: String = "Player"
@export var description: String = "A player of the game"
@export var avatar: Texture2D = null
## Filename stem under res://assets/textures/avatars/ (e.g. "00000").
@export var avatar_id: String = ""
@export var date_joined: float = Time.get_unix_time_from_system()
## Last joined room (for unexpected-disconnect rejoin). Cleared on voluntary leave.
@export var last_room_code: String = ""
@export var last_host_address: String = ""
@export var last_host_port: int = 13637


func to_profile() -> PlayerProfile:
	var profile_avatar_id: Variant = avatar_id
	return PlayerProfile.new(name, profile_avatar_id)


static func from_profile(player_id: PlayerId, profile: PlayerProfile) -> PlayerData:
	var data := PlayerData.new()
	data.uid = player_id.value
	data.name = profile.nickname
	if profile.avatar_id != null:
		data.avatar_id = str(profile.avatar_id)
		data.avatar = AvatarUtils.load_texture(data.avatar_id)
	return data
