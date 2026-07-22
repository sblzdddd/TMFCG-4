class_name MatchCardController
extends Node
## Host-authoritative GameState (deck / hands / graveyards). Clients apply filtered snapshots.

const SOFT_HAND_TARGET := 5

var _session: RoomSessionNode
var _rpc: MatchCardRpc
var state: GameState = null


func setup(session: RoomSessionNode) -> void:
	_session = session
	_rpc = MatchCardRpc.new()
	_rpc.name = "MatchCardRpc"
	add_child(_rpc)
	_rpc.card_snapshot_received.connect(_on_card_snapshot)
	_rpc.cards_drawn_received.connect(_on_cards_drawn_rpc)
	_rpc.play_requested.connect(handle_play_request)
	_rpc.pass_requested.connect(handle_pass_request)
	session.room_changed.connect(_on_room_changed)


func send_play_request(card_ids: Array) -> void:
	if _rpc != null:
		_rpc.send_play(card_ids)


func send_pass_request() -> void:
	if _rpc != null:
		_rpc.send_pass()


func handle_play_request(peer_id: int, card_ids: Array) -> void:
	if not _is_host():
		return
	var uid := _uid_for_peer(peer_id)
	var match_state := _match_state()
	if uid.is_empty() or not _is_active_turn(uid, match_state):
		return
	_ensure_initialized()
	if state == null:
		return
	var hand := state.get_player_hand(PlayerId.from_string(uid))
	if hand == null:
		return
	var by_id: Dictionary = {}
	for card in hand.get_all_cards():
		by_id[card.instance_id.value] = card
	var selected: Array[Card] = []
	for raw in card_ids:
		var id := str(raw)
		if by_id.has(id) and not selected.has(by_id[id]):
			selected.append(by_id[id])
	if selected.is_empty():
		return
	var moved := state.record_play(PlayerId.from_string(uid), selected)
	if moved.is_empty():
		return
	state.passes_count = 0
	state.trick_winner_id = PlayerId.from_string(uid)
	_broadcast()
	if _session.match_controller != null:
		_session.match_controller.advance_turn(MatchController.TURN_GAP_SEC)


func handle_pass_request(peer_id: int) -> void:
	if not _is_host():
		return
	var uid := _uid_for_peer(peer_id)
	var match_state := _match_state()
	if uid.is_empty() or not _is_active_turn(uid, match_state):
		return
	_ensure_initialized()
	if state == null:
		return
	state.passes_count += 1
	_broadcast()
	var order := match_state.order
	var next_uid := order.next_after(uid)
	var winner := state.trick_winner_id.value if state.trick_winner_id != null else ""
	if (
		not winner.is_empty()
		and next_uid == winner
		and state.passes_count >= order.size() - 1
		and _session.match_controller != null
	):
		_session.match_controller.end_round()
	elif _session.match_controller != null:
		_session.match_controller.advance_turn(MatchController.TURN_GAP_SEC)


func clear() -> void:
	state = null
	_emit_changed()


func get_state() -> GameState:
	return state


## Called from MatchController when phase/active changes.
func sync_match_runtime(active_uid: String, phase: MatchPhase.Phase) -> void:
	if not _is_host():
		return
	if phase != MatchPhase.Phase.INITIALIZATION:
		_ensure_initialized()
	if state == null:
		return
	state.current_phase = phase
	if not active_uid.is_empty():
		var idx := state.player_index(PlayerId.from_string(active_uid))
		if idx >= 0:
			state.current_player_index = idx


func send_state_to(peer_id: int, uid: String) -> void:
	if not _is_host() or state == null or _rpc == null:
		return
	_rpc.send_snapshot_to(peer_id, state.to_dict_for_viewer(uid))


func end_round() -> void:
	if not _is_host():
		return
	_ensure_initialized()
	if state == null:
		return
	state.end_round()
	_broadcast()


## Draws [param count] cards from deck into [param uid]'s hand (mark_hidden).
func draw_to_player(uid: String, count: int = 1) -> Array[Card]:
	if not _is_host() or uid.is_empty() or count <= 0:
		return []
	_ensure_initialized()
	if state == null or state.deck == null:
		return []
	var hand := state.get_player_hand(PlayerId.from_string(uid))
	if hand == null:
		return []
	var available := state.deck.get_size()
	var n := mini(count, available)
	if n <= 0:
		return []
	var selected: Array[Card] = []
	for i in n:
		selected.append(state.deck.get_card(i))
	var moved := state.transfer_cards(state.deck, hand, selected, true)
	_notify_drawn(uid, moved)
	_broadcast()
	return moved


## Soft-fill each hand toward SOFT_HAND_TARGET.
func draw_for_all_soft(target: int = SOFT_HAND_TARGET) -> void:
	if not _is_host():
		return
	_ensure_initialized()
	if state == null or state.deck == null:
		return
	var drawn_by_uid: Dictionary = {}
	for player in state.players:
		if player == null or player.hand == null or player.player_id == null:
			continue
		var need := maxi(0, target - player.hand.get_size())
		if need <= 0:
			continue
		var n := mini(need, state.deck.get_size())
		if n <= 0:
			break
		var selected: Array[Card] = []
		for i in n:
			selected.append(state.deck.get_card(i))
		var moved := state.transfer_cards(state.deck, player.hand, selected, true)
		if not moved.is_empty():
			drawn_by_uid[player.player_id.value] = moved
	if drawn_by_uid.is_empty():
		return
	for uid in drawn_by_uid.keys():
		var moved_variant: Variant = drawn_by_uid[uid]
		var moved: Array[Card] = []
		if moved_variant is Array:
			for item in moved_variant:
				if item is Card:
					moved.append(item)
		_notify_drawn(str(uid), moved)
	_broadcast()


func transfer(
	from_id: String,
	to_id: String,
	cards: Array[Card],
	mark_hidden: bool = false,
) -> Array[Card]:
	if not _is_host():
		return []
	_ensure_initialized()
	if state == null:
		return []
	var from_holder := state.get_holder(from_id)
	var to_holder := state.get_holder(to_id)
	var moved := state.transfer_cards(from_holder, to_holder, cards, mark_hidden)
	if not moved.is_empty():
		_broadcast()
	return moved


func record_play(player_uid: String, cards: Array[Card]) -> Array[Card]:
	if not _is_host():
		return []
	_ensure_initialized()
	if state == null:
		return []
	var moved := state.record_play(PlayerId.from_string(player_uid), cards)
	if not moved.is_empty():
		_broadcast()
	return moved


func _ensure_initialized() -> void:
	if not _is_host():
		return
	if state != null:
		_sync_players_with_order()
		return
	var match_state: MatchRuntimeState = null
	if _session.match_controller != null:
		match_state = _session.match_controller.get_state()
	if match_state == null or match_state.order.is_empty():
		return
	var deck_data := _session.get_resolved_deck()
	var deck := Deck.from_deck_data(deck_data)
	var players: Array[PlayerState] = []
	for uid in match_state.order.uids:
		players.append(PlayerState.new(PlayerId.from_string(uid)))
	state = GameState.new(deck, players)
	if match_state.phase != MatchPhase.Phase.INITIALIZATION:
		state.current_phase = match_state.phase
	_broadcast()


func _sync_players_with_order() -> void:
	if state == null or _session.match_controller == null:
		return
	var match_state := _session.match_controller.get_state()
	if match_state == null:
		return
	var existing: Dictionary = {}
	for player in state.players:
		if player.player_id != null:
			existing[player.player_id.value] = player
	var rebuilt: Array[PlayerState] = []
	for uid in match_state.order.uids:
		if existing.has(uid):
			rebuilt.append(existing[uid])
		else:
			rebuilt.append(PlayerState.new(PlayerId.from_string(uid)))
	if rebuilt.size() != state.players.size():
		state.players = rebuilt
		_broadcast()
	else:
		for i in rebuilt.size():
			if rebuilt[i] != state.players[i]:
				state.players = rebuilt
				_broadcast()
				break


func _notify_drawn(uid: String, moved: Array[Card]) -> void:
	if moved.is_empty() or _session == null:
		return
	var ids: Array[String] = []
	for card in moved:
		ids.append(card.instance_id.value)
	# Local host recipient.
	if PlayerDataStore.data != null and PlayerDataStore.data.uid == uid:
		_session.cards_drawn.emit(ids)
		return
	# Remote recipient.
	if _session.current_room == null or _rpc == null:
		return
	for member in _session.current_room.get_members():
		if member.uid == uid and member.peer_id > 1:
			_rpc.send_cards_drawn_to(member.peer_id, ids)
			return


func _broadcast() -> void:
	if state == null or _session == null:
		return
	_emit_changed()
	if not _is_host() or _rpc == null or _session.current_room == null:
		return
	for member in _session.current_room.get_members():
		if member.peer_id <= 0:
			continue
		# Host applies local viewer projection via _emit_changed (full local state for host).
		# Peers get filtered snapshots. Host peer_id is typically 1.
		if member.uid == (
			PlayerDataStore.data.uid if PlayerDataStore.data != null else ""
		):
			continue
		_rpc.send_snapshot_to(member.peer_id, state.to_dict_for_viewer(member.uid))


func _emit_changed() -> void:
	if _session != null:
		_session.card_state_changed.emit(state)


func _on_card_snapshot(snapshot: Dictionary) -> void:
	if _session != null and _session.is_leaving_voluntarily():
		return
	state = GameState.from_dict(snapshot)
	_hydrate_card_data_from_deck(state)
	_emit_changed()


## Client snapshots only carry cardId / rank / suit — restore portraits from the
## resolved room deck so hand / draw-preview views keep character visuals.
func _hydrate_card_data_from_deck(game_state: GameState) -> void:
	if game_state == null or _session == null:
		return
	var deck_data := _session.get_resolved_deck()
	if deck_data == null:
		return
	var by_id: Dictionary = {}
	for template in deck_data.cards:
		if template == null or template.cardId.is_empty():
			continue
		by_id[template.cardId] = template
	if by_id.is_empty():
		return
	for holder in game_state.all_card_holders():
		if holder == null:
			continue
		for card in holder.get_all_cards():
			if card == null or card.data == null:
				continue
			if card.data.visual != null:
				continue
			var card_id := card.data.cardId
			if card_id.is_empty() or not by_id.has(card_id):
				continue
			var template: CardData = by_id[card_id]
			var hydrated := template.duplicate(true) as CardData
			if hydrated == null:
				continue
			card.data = hydrated


func _on_cards_drawn_rpc(card_ids: Array) -> void:
	var ids: Array[String] = []
	for id in card_ids:
		ids.append(str(id))
	if _session != null:
		_session.cards_drawn.emit(ids)


func _on_room_changed(room: RoomData) -> void:
	if room == null:
		clear()


func _is_host() -> bool:
	return _session != null and _session.is_local_host()


func _match_state() -> MatchRuntimeState:
	if _session == null or _session.match_controller == null:
		return null
	return _session.match_controller.get_state()


func _is_active_turn(uid: String, match_state: MatchRuntimeState) -> bool:
	return (
		match_state != null
		and match_state.phase == MatchPhase.Phase.TURN_PLAY
		and match_state.active_uid == uid
	)


func _uid_for_peer(peer_id: int) -> String:
	if _session == null or _session.current_room == null:
		return ""
	var idx := _session.current_room.find_member_peer(peer_id)
	if idx < 0:
		return ""
	var members := _session.current_room.get_members()
	if idx >= members.size():
		return ""
	return members[idx].uid
