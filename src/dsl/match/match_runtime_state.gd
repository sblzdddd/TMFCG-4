class_name MatchRuntimeState
extends RefCounted
## Host-authoritative match phase + play order (separate from GameState DSL).

var phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION
var order: PlayerOrder = PlayerOrder.new()
var active_uid: String = ""


func _init(
	p_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION,
	p_order: PlayerOrder = null,
	p_active_uid: String = "",
) -> void:
	phase = p_phase
	order = p_order if p_order != null else PlayerOrder.new()
	active_uid = p_active_uid


func clear() -> void:
	phase = MatchPhase.Phase.INITIALIZATION
	order = PlayerOrder.new()
	active_uid = ""


func to_dict() -> Dictionary:
	return {
		"phase": MatchPhase.Phase.find_key(phase),
		"order": order.to_dict() if order != null else {},
		"activeUid": active_uid,
	}


static func from_dict(dict: Dictionary) -> MatchRuntimeState:
	var order_raw: Variant = dict.get("order", {})
	var parsed_order := PlayerOrder.from_dict(order_raw if order_raw is Dictionary else {})
	return MatchRuntimeState.new(
		_phase_from_name(str(dict.get("phase", "INITIALIZATION"))),
		parsed_order,
		str(dict.get("activeUid", "")),
	)


static func _phase_from_name(name: String) -> MatchPhase.Phase:
	match name.to_upper():
		"INITIALIZATION":
			return MatchPhase.Phase.INITIALIZATION
		"TURN_PLAY":
			return MatchPhase.Phase.TURN_PLAY
		"ROUND_RESOLUTION":
			return MatchPhase.Phase.ROUND_RESOLUTION
		"END_GAME_PLAY":
			return MatchPhase.Phase.END_GAME_PLAY
		"GAME_OVER":
			return MatchPhase.Phase.GAME_OVER
		_:
			return MatchPhase.Phase.INITIALIZATION
