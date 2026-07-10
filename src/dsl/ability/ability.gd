class_name Ability
extends RefCounted

var id: String = "0"
var instance_id: AbilityInstanceId
var trigger_type: TriggerType.Type = TriggerType.Type.ON_PLAY
var effects: Array = []
var enabled: bool = false


func _init(
	p_id: String = "0",
	p_instance_id: AbilityInstanceId = null,
	p_trigger_type: TriggerType.Type = TriggerType.Type.ON_PLAY,
	p_effects: Array = [],
	p_enabled: bool = false,
) -> void:
	id = p_id
	instance_id = p_instance_id if p_instance_id != null else AbilityInstanceId.new()
	trigger_type = p_trigger_type
	effects = p_effects.duplicate()
	enabled = p_enabled
