class_name SkillInfo
extends RefCounted

var name: String = ""
var description: String = ""


static func from_stored(stored: String) -> SkillInfo:
	var info := SkillInfo.new()
	var break_idx := stored.find("\n")
	if break_idx < 0:
		info.name = stored
		info.description = ""
	else:
		info.name = stored.substr(0, break_idx)
		info.description = stored.substr(break_idx + 1)
	return info


func to_stored() -> String:
	return "%s\n%s" % [name, description]
