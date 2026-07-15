class_name NetConst
extends Object

const GAME_PORT := 13637
const DISCOVERY_PORT := 13638
const DISCONNECT_GRACE_SEC := 15.0
const BROADCAST_INTERVAL := 1.0
const DISCOVERY_TTL_SEC := 3.0
const RANDOM_MATCH_WAIT_SEC := 2.0
const REJOIN_ATTEMPTS := 2
const JOIN_TIMEOUT_SEC := 5.0
const ROOM_CODE_LENGTH := 8
const ROOM_CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const COMBAT_SCENE := "res://definitions/levels/combat.tscn"
const TITLE_SCENE := "res://definitions/levels/title.tscn"


static func generate_room_code(length: int = ROOM_CODE_LENGTH) -> String:
	var out := ""
	for _i in length:
		out += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return out
