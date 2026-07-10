class_name FreezeEffect
extends EffectAction

var duration: int = 0
var target_id: Variant = null


func _init(
	p_reversible: bool,
	p_duration: int,
	p_target_id: Variant = null,
) -> void:
	reversible = p_reversible
	duration = p_duration
	target_id = p_target_id
