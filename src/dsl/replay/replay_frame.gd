class_name ReplayFrame
extends RefCounted

var timestamp: int = 0
var type: ReplayFrameType.Type
var data: GameState


func _init(p_timestamp: int, p_type: ReplayFrameType.Type, p_data: GameState) -> void:
	timestamp = p_timestamp
	type = p_type
	data = p_data


func _to_string() -> String:
	return "=== START ReplayFrame %s === \ntimestamp: %d, data: \n%s\n=== END ReplayFrame ===" % [
		ReplayFrameType.Type.find_key(type),
		timestamp,
		data,
	]
