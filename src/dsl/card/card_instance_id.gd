class_name CardInstanceId
extends RefCounted

var value: String


func _init(id_value: String = "") -> void:
	value = id_value if not id_value.is_empty() else _generate_uuid()


static func from_string(id_value: String) -> CardInstanceId:
	return CardInstanceId.new(id_value)


func _to_string() -> String:
	return value


static func _generate_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5], bytes[6], bytes[7],
		bytes[8], bytes[9], bytes[10], bytes[11],
		bytes[12], bytes[13], bytes[14], bytes[15],
	]
