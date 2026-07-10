class_name DrawEffect
extends EffectAction

var count: int = 0
var allow_hand_overflow: bool = false


func _init(
	p_count: int,
	p_reversible: bool = false,
	p_allow_hand_overflow: bool = false,
) -> void:
	reversible = p_reversible
	count = p_count
	allow_hand_overflow = p_allow_hand_overflow
