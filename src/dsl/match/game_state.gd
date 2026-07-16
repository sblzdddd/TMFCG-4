class_name GameState
extends RefCounted

signal cards_transferred(
	from: CardHolder,
	to: CardHolder,
	cards: Array,
	mark_hidden: bool,
	ignore_passives: bool,
)

var deck: Deck
var graveyard: Graveyard
var players: Array[PlayerState] = []
var current_player_index: int = 0
var direction: PlayDirection.Direction = PlayDirection.Direction.CLOCKWISE
var current_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION
var current_trick_combo: CardCombination = null
var trick_winner_id: PlayerId = null
var passes_count: int = 0
var placements: Array[PlayerId] = []


func _init(
	p_deck: Deck = null,
	p_players: Array[PlayerState] = [],
	p_current_player_index: int = 0,
	p_direction: PlayDirection.Direction = PlayDirection.Direction.CLOCKWISE,
	p_current_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION,
	p_current_trick_combo: CardCombination = null,
	p_trick_winner_id: PlayerId = null,
	p_passes_count: int = 0,
	p_placements: Array[PlayerId] = [],
	p_graveyard: Graveyard = null,
) -> void:
	deck = p_deck if p_deck != null else Deck.empty()
	graveyard = p_graveyard if p_graveyard != null else Graveyard.new()
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


func get_current_player_hand() -> PlayerHand:
	if players.is_empty():
		return null
	return players[current_player_index].hand


func get_player_hand(player_id: PlayerId) -> PlayerHand:
	var index := player_index(player_id)
	if index < 0:
		return null
	return players[index].hand


func all_player_hands() -> Array[PlayerHand]:
	var hands: Array[PlayerHand] = []
	for player in players:
		hands.append(player.hand)
	return hands


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


func transfer_cards(
	from: CardHolder,
	to: CardHolder,
	cards: Array[Card],
	mark_hidden: bool = false,
	ignore_passives: bool = false,
) -> Array[Card]:
	if from == null or to == null:
		return []
	var moved := from.transfer_to(to, cards, mark_hidden, ignore_passives)
	if not moved.is_empty():
		cards_transferred.emit(from, to, moved, mark_hidden, ignore_passives)
	return moved


func update_player(player_id: PlayerId, transform: Callable) -> void:
	var index := player_index(player_id)
	if index < 0:
		return
	players[index] = transform.call(players[index])


func to_dict() -> Dictionary:
	var player_dicts: Array = []
	for player in players:
		player_dicts.append(player.to_dict())
	var placement_values: Array = []
	for placement in placements:
		placement_values.append(placement.value)
	return {
		"deck": deck.to_dict() if deck != null else {},
		"graveyard": graveyard.to_dict() if graveyard != null else {},
		"players": player_dicts,
		"currentPlayerIndex": current_player_index,
		"direction": PlayDirection.Direction.find_key(direction),
		"currentPhase": MatchPhase.Phase.find_key(current_phase),
		"trickWinnerId": trick_winner_id.value if trick_winner_id != null else "",
		"passesCount": passes_count,
		"placements": placement_values,
	}


static func from_dict(dict: Dictionary) -> GameState:
	var player_states: Array[PlayerState] = []
	var raw_players: Variant = dict.get("players", [])
	if raw_players is Array:
		for item in raw_players:
			if item is Dictionary:
				player_states.append(PlayerState.from_dict(item))

	var placement_ids: Array[PlayerId] = []
	var raw_placements: Variant = dict.get("placements", [])
	if raw_placements is Array:
		for item in raw_placements:
			placement_ids.append(PlayerId.from_string(str(item)))

	var trick_winner_raw := str(dict.get("trickWinnerId", ""))
	var trick_winner: PlayerId = null
	if not trick_winner_raw.is_empty():
		trick_winner = PlayerId.from_string(trick_winner_raw)

	var deck_dict: Variant = dict.get("deck", {})
	var graveyard_dict: Variant = dict.get("graveyard", {})
	return GameState.new(
		Deck.from_dict(deck_dict if deck_dict is Dictionary else {}),
		player_states,
		int(dict.get("currentPlayerIndex", 0)),
		_direction_from_name(str(dict.get("direction", "CLOCKWISE"))),
		_phase_from_name(str(dict.get("currentPhase", "INITIALIZATION"))),
		null,
		trick_winner,
		int(dict.get("passesCount", 0)),
		placement_ids,
		Graveyard.from_dict(graveyard_dict if graveyard_dict is Dictionary else {}),
	)


func _to_string() -> String:
	return "phase: %s\ndeck size: %d\ngraveyard size: %d\nplayers: %s\ncurrent player: %d\ndir: %s\npasses: %d" % [
		MatchPhase.Phase.find_key(current_phase),
		deck.get_size() if deck != null else 0,
		graveyard.get_size() if graveyard != null else 0,
		", ".join(players.map(func(p: PlayerState) -> String: return str(p.player_id))),
		current_player_index,
		PlayDirection.Direction.find_key(direction),
		passes_count,
	]


static func _direction_from_name(name: String) -> PlayDirection.Direction:
	match name.to_upper():
		"COUNTER_CLOCKWISE":
			return PlayDirection.Direction.COUNTER_CLOCKWISE
		_:
			return PlayDirection.Direction.CLOCKWISE


static func _phase_from_name(name: String) -> MatchPhase.Phase:
	match name.to_upper():
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
