class_name StealEffect
extends EffectAction

var count: int = 0
var target_player_id: String = ""
var strategy: StealStrategy.Strategy = StealStrategy.Strategy.RANDOM
var steal_range: Vector2i = Vector2i(0, 13)


func _init(
	p_reversible: bool,
	p_count: int,
	p_target_player_id: String,
	p_strategy: StealStrategy.Strategy = StealStrategy.Strategy.RANDOM,
	p_steal_range: Vector2i = Vector2i(0, 13),
) -> void:
	reversible = p_reversible
	count = p_count
	target_player_id = p_target_player_id
	strategy = p_strategy
	steal_range = p_steal_range
