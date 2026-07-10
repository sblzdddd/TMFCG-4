class_name GameState
extends RefCounted

var deck: Deck
var players: Array[PlayerState] = []
var current_player_index: int = 0
var direction: PlayDirection.Direction = PlayDirection.Direction.CLOCKWISE
var current_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION
var current_trick_combo: CardCombination = null
var trick_winner_id: PlayerId = null
var passes_count: int = 0
var placements: Array[PlayerId] = []


func _init(
	p_deck: Deck,
	p_players: Array[PlayerState],
	p_current_player_index: int = 0,
	p_direction: PlayDirection.Direction = PlayDirection.Direction.CLOCKWISE,
	p_current_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION,
	p_current_trick_combo: CardCombination = null,
	p_trick_winner_id: PlayerId = null,
	p_passes_count: int = 0,
	p_placements: Array[PlayerId] = [],
) -> void:
	deck = p_deck
	players = p_players.duplicate()
	current_player_index = p_current_player_index
	direction = p_direction
	current_phase = p_current_phase
	current_trick_combo = p_current_trick_combo
	trick_winner_id = p_trick_winner_id
	passes_count = p_passes_count
	placements = p_placements.duplicate()


func get_current_player_id() -> PlayerId:
	return players[current_player_index].player_id


func get_active_players() -> Array[PlayerState]:
	var placement_ids: Dictionary = {}
	for placement in placements:
		placement_ids[placement.value] = true
	var active: Array[PlayerState] = []
	for player in players:
		if not placement_ids.has(player.player_id.value):
			active.append(player)
	return active


func player_index(player_id: PlayerId) -> int:
	for i in players.size():
		if players[i].player_id.value == player_id.value:
			return i
	return -1


func get_next_player_index(from_index: int) -> int:
	var step := 1 if direction == PlayDirection.Direction.CLOCKWISE else -1
	return (from_index + step + players.size()) % players.size()


func update_player(player_id: PlayerId, transform: Callable) -> GameState:
	var index := player_index(player_id)
	var updated_players := players.duplicate()
	updated_players[index] = transform.call(updated_players[index])
	return GameState.new(
		deck,
		updated_players,
		current_player_index,
		direction,
		current_phase,
		current_trick_combo,
		trick_winner_id,
		passes_count,
		placements,
	)


func _to_string() -> String:
	return "phase: %s\ndeck size: %d\nplayers: %s\ncurrent player: %d\ndir: %s\npasses: %d" % [
		MatchPhase.Phase.find_key(current_phase),
		deck.get_size(),
		", ".join(players.map(func(p: PlayerState) -> String: return str(p.player_id))),
		current_player_index,
		PlayDirection.Direction.find_key(direction),
		passes_count,
	]
