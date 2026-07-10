class_name PlayerData
extends Resource

@export var uid: String = "user-0"
@export var name: String = "Player"
@export var description: String = "A player of the game"
@export var avatar: Texture2D = null
@export var avatar_id: int = -1
@export var date_joined: float = Time.get_unix_time_from_system()


func to_profile() -> PlayerProfile:
	var profile_avatar_id: Variant = avatar_id if avatar_id >= 0 else null
	return PlayerProfile.new(name, profile_avatar_id)


static func from_profile(player_id: PlayerId, profile: PlayerProfile) -> PlayerData:
	var data := PlayerData.new()
	data.uid = player_id.value
	data.name = profile.nickname
	if profile.avatar_id != null:
		data.avatar_id = int(profile.avatar_id)
	return data

