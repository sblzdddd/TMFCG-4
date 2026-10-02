class_name NetConst
extends Object

const GAME_PORT := 13637
const DISCONNECT_GRACE_SEC := 120.0
const REJOIN_ATTEMPTS := 2
const JOIN_TIMEOUT_SEC := 5.0
const ROOM_CODE_LENGTH := 8
const ROOM_CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

const LOCAL_ADDR := "127.0.0.1"
const LOCAL_JOIN_ATTEMPTS := 20
const LOCAL_JOIN_RETRY_SEC := 0.5

static func generate_room_code(length: int = ROOM_CODE_LENGTH) -> String:
	var out := ""
	for _i in length:
		out += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return out
