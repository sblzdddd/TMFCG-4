class_name GameState
extends RefCounted

const TemporaryGraveyardType := preload(
	"res://src/dsl/card_holder/temporary_graveyard.gd"
)

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
var current_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION
var current_trick_combo: CardCombination = null
var trick_winner_id: PlayerId = null
var passes_count: int = 0
var placements: Array[PlayerId] = []
## Card instance IDs in exact global play order for the current round.
var play_history_instance_ids: Array[String] = []
## Seats that passed this cycle; cleared when that seat's next turn starts (like temp GY).
var passed_uids: Array[String] = []


func _init(
	p_deck: Deck = null,
	p_players: Array[PlayerState] = [],
	p_current_player_index: int = 0,
	p_current_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION,
	p_current_trick_combo: CardCombination = null,
	p_trick_winner_id: PlayerId = null,
	p_passes_count: int = 0,
	p_placements: Array[PlayerId] = [],
	p_graveyard: Graveyard = null,
	p_play_history_instance_ids: Array[String] = [],
	p_passed_uids: Array[String] = [],
) -> void:
	deck = p_deck if p_deck != null else Deck.empty()
	graveyard = p_graveyard if p_graveyard != null else Graveyard.new()
	players = p_players.duplicate()
	current_player_index = p_current_player_index
	current_phase = p_current_phase
	current_trick_combo = p_current_trick_combo
	trick_winner_id = p_trick_winner_id
	passes_count = p_passes_count
	placements = p_placements.duplicate()
	play_history_instance_ids = p_play_history_instance_ids.duplicate()
	passed_uids = p_passed_uids.duplicate()


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


func get_player_temporary_graveyard(player_id: PlayerId) -> TemporaryGraveyardType:
	var index := player_index(player_id)
	if index < 0:
		return null
	return players[index].temporary_graveyard


func all_player_hands() -> Array[PlayerHand]:
	var hands: Array[PlayerHand] = []
	for player in players:
		hands.append(player.hand)
	return hands


func all_card_holders() -> Array[CardHolder]:
	var holders: Array[CardHolder] = []
	if deck != null:
		holders.append(deck)
	if graveyard != null:
		holders.append(graveyard)
	for player in players:
		if player.hand != null:
			holders.append(player.hand)
		if player.temporary_graveyard != null:
			holders.append(player.temporary_graveyard)
	return holders


func sort_non_deck_holders() -> void:
	var wild_rank := deck.wild_rank if deck != null else CardEnums.Rank.NONE
	for holder in all_card_holders():
		if holder != null and holder.kind != CardHolder.Kind.DECK:
			holder.sort_by_rank(wild_rank)


func get_holder(holder_id: String) -> CardHolder:
	for holder in all_card_holders():
		if holder.holder_id == holder_id:
			return holder
	return null


func get_holder_by_id(holder_id: String) -> CardHolder:
	return get_holder(holder_id)


func get_holder_containing_card(instance_id: String) -> CardHolder:
	for holder in all_card_holders():
		for card in holder.get_all_cards():
			if card.instance_id.value == instance_id:
				return holder
	return null


func get_card_by_instance_id(instance_id: String) -> Card:
	var holder := get_holder_containing_card(instance_id)
	if holder == null:
		return null
	for card in holder.get_all_cards():
		if card.instance_id.value == instance_id:
			return card
	return null


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

# idk how to represent
# func get_next_player_index(from_index: int) -> int:
# 	var step := 1
# 	return (from_index + step + players.size()) % players.size()


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


func record_play(player_id: PlayerId, cards: Array[Card]) -> Array[Card]:
	var hand := get_player_hand(player_id)
	var temporary_graveyard := get_player_temporary_graveyard(player_id)
	if hand == null or temporary_graveyard == null or cards.is_empty():
		return []
	var playable_cards: Array[Card] = []
	var hand_cards := hand.get_all_cards()
	for card in cards:
		if hand_cards.has(card) and not playable_cards.has(card):
			card.make_public()
			playable_cards.append(card)
	var moved := transfer_cards(hand, temporary_graveyard, playable_cards)
	for card in moved:
		play_history_instance_ids.append(card.instance_id.value)
	return moved


## Move one player's temp-GY cards into the main graveyard (turn-start clear).
func flush_player_temporary_graveyard(player_id: PlayerId) -> Array[Card]:
	var temporary_graveyard := get_player_temporary_graveyard(player_id)
	if temporary_graveyard == null or graveyard == null:
		return []
	var cards := temporary_graveyard.get_all_cards()
	if cards.is_empty():
		return []
	return transfer_cards(temporary_graveyard, graveyard, cards)


func mark_passed(uid: String) -> void:
	if uid.is_empty() or passed_uids.has(uid):
		return
	passed_uids.append(uid)


## Clears a seat's pass marker (turn-start). Returns true if one was removed.
func clear_passed(uid: String) -> bool:
	var idx := passed_uids.find(uid)
	if idx < 0:
		return false
	passed_uids.remove_at(idx)
	return true


func has_passed(uid: String) -> bool:
	return not uid.is_empty() and passed_uids.has(uid)


func end_round() -> Array[Card]:
	var flushed: Array[Card] = []
	for instance_id in play_history_instance_ids:
		var holder := get_holder_containing_card(instance_id)
		if holder == null or holder.kind != CardHolder.Kind.TEMPORARY_GRAVEYARD:
			continue
		var card: Card = null
		for candidate in holder.get_all_cards():
			if candidate.instance_id.value == instance_id:
				card = candidate
				break
		if card == null:
			continue
		var moved := transfer_cards(holder, graveyard, [card])
		if not moved.is_empty():
			flushed.append(moved[0])
	play_history_instance_ids.clear()
	passes_count = 0
	passed_uids.clear()
	# Keep trick_winner_id so the winner leads the next round (must-play + UI).
	current_trick_combo = null
	return flushed


## True when [param uid] won the last trick and has not yet led this round,
## and still has cards (empty-hand winners may pass).
func must_lead(uid: String) -> bool:
	if uid.is_empty() or trick_winner_id == null or trick_winner_id.value != uid:
		return false
	if not play_history_instance_ids.is_empty():
		return false
	var hand := get_player_hand(PlayerId.from_string(uid))
	return hand != null and hand.get_size() > 0


## True while the last trick winner still needs to lead (history empty).
func is_awaiting_lead() -> bool:
	return (
		trick_winner_id != null
		and not trick_winner_id.value.is_empty()
		and play_history_instance_ids.is_empty()
	)


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
		"currentPhase": MatchPhase.Phase.find_key(current_phase),
		"currentTrickCombo": CardCombinationSerde.to_dict(current_trick_combo),
		"trickWinnerId": trick_winner_id.value if trick_winner_id != null else "",
		"passesCount": passes_count,
		"placements": placement_values,
		"playHistoryInstanceIds": play_history_instance_ids.duplicate(),
		"passedUids": passed_uids.duplicate(),
	}


func to_dict_for_viewer(viewer_uid: String) -> Dictionary:
	var player_dicts: Array = []
	for player in players:
		player_dicts.append(player.to_dict_for_viewer(viewer_uid))
	var placement_values: Array = []
	for placement in placements:
		placement_values.append(placement.value)
	return {
		"deck": deck.to_dict_for_viewer(viewer_uid) if deck != null else {},
		"graveyard": (
			graveyard.to_dict_for_viewer(viewer_uid)
			if graveyard != null
			else {}
		),
		"players": player_dicts,
		"currentPlayerIndex": current_player_index,
		"currentPhase": MatchPhase.Phase.find_key(current_phase),
		"currentTrickCombo": CardCombinationSerde.to_dict(current_trick_combo),
		"trickWinnerId": trick_winner_id.value if trick_winner_id != null else "",
		"passesCount": passes_count,
		"placements": placement_values,
		"playHistoryInstanceIds": play_history_instance_ids.duplicate(),
		"passedUids": passed_uids.duplicate(),
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

	var play_history_ids: Array[String] = []
	var raw_play_history: Variant = dict.get("playHistoryInstanceIds", [])
	if raw_play_history is Array:
		for item in raw_play_history:
			play_history_ids.append(str(item))

	var passed: Array[String] = []
	var raw_passed: Variant = dict.get("passedUids", [])
	if raw_passed is Array:
		for item in raw_passed:
			var uid := str(item)
			if not uid.is_empty() and not passed.has(uid):
				passed.append(uid)

	var deck_dict: Variant = dict.get("deck", {})
	var graveyard_dict: Variant = dict.get("graveyard", {})
	var combo_raw: Variant = dict.get("currentTrickCombo", {})
	var combo: CardCombination = null
	if combo_raw is Dictionary:
		combo = CardCombinationSerde.from_dict(combo_raw as Dictionary)
	var state := GameState.new(
		Deck.from_dict(deck_dict if deck_dict is Dictionary else {}),
		player_states,
		int(dict.get("currentPlayerIndex", 0)),
		_phase_from_name(str(dict.get("currentPhase", "INITIALIZATION"))),
		combo,
		trick_winner,
		int(dict.get("passesCount", 0)),
		placement_ids,
		Graveyard.from_dict(graveyard_dict if graveyard_dict is Dictionary else {}),
		play_history_ids,
		passed,
	)
	# Preserve the authoritative order in the snapshot. Hidden cards have no
	# rank/suit on clients, so sorting them here would scramble visual indices.
	return state


func _to_string() -> String:
	return "phase: %s\ndeck size: %d\ngraveyard size: %d\nplayers: %s\ncurrent player: %d\npasses: %d" % [
		MatchPhase.Phase.find_key(current_phase),
		deck.get_size() if deck != null else 0,
		graveyard.get_size() if graveyard != null else 0,
		", ".join(players.map(func(p: PlayerState) -> String: return str(p.player_id))),
		current_player_index,
		passes_count,
	]


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
