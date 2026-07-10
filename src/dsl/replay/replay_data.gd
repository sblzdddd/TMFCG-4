class_name ReplayData
extends RefCounted

var name: String = ""
var frames: Array[ReplayFrame] = []


func _init(p_name: String, p_frames: Array[ReplayFrame] = []) -> void:
	name = p_name
	frames = p_frames.duplicate()


func _to_string() -> String:
	return "ReplayData(\nname: '%s', frames: \n%s\n)" % [
		name,
		"\n".join(frames.map(func(frame: ReplayFrame) -> String: return str(frame))),
	]
