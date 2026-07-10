class_name AbilityInstanceId
extends RefCounted

var value: String


func _init(id_value: String = "") -> void:
	value = id_value if not id_value.is_empty() else CardInstanceId.new().value


static func from_string(id_value: String) -> AbilityInstanceId:
	return AbilityInstanceId.new(id_value)
