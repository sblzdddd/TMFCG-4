class_name PlayerId
extends RefCounted

var value: String


func _init(id_value: String = "") -> void:
	value = id_value if not id_value.is_empty() else _generate_uuid()


static func from_string(id_value: String) -> PlayerId:
	return PlayerId.new(id_value)


func _to_string() -> String:
	return value


static func _generate_uuid() -> String:
	return CardInstanceId.new().value
