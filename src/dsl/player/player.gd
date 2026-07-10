class_name Player
extends RefCounted

var id: PlayerId
var profile: PlayerProfile


func _init(p_id: PlayerId, p_profile: PlayerProfile) -> void:
	id = p_id
	profile = p_profile
