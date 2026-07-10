class_name PlayerState
extends RefCounted

var player_id: PlayerId
var hand: Array[Card] = []


func _init(p_player_id: PlayerId, p_hand: Array[Card] = []) -> void:
	player_id = p_player_id
	hand = p_hand.duplicate()
