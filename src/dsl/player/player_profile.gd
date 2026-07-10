class_name PlayerProfile
extends RefCounted

var nickname: String
var avatar_id: Variant = null


func _init(p_nickname: String, p_avatar_id: Variant = null) -> void:
	nickname = p_nickname
	avatar_id = p_avatar_id
