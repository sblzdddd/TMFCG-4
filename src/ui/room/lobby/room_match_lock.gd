class_name RoomMatchLock
extends RefCounted
## True while joins/settings are closed (match in progress). Unlocked in lobby and at GAME_OVER.


static func is_match_locked() -> bool:
	if RoomSession.match_controller == null:
		return false
	return not RoomSession.match_controller.accepts_new_joins()
