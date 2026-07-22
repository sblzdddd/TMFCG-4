class_name RoomMatchLock
extends RefCounted
## True while joins are closed (match in progress or finished).


static func is_match_locked() -> bool:
	if RoomSession.match_controller == null:
		return false
	return not RoomSession.match_controller.accepts_new_joins()
