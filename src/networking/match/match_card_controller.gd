class_name MatchCardController
extends Node
## Host-authoritative GameState (deck / hands / graveyards). Clients apply filtered snapshots.

const SOFT_HAND_TARGET := SoftDraw.TARGET

var _session: Node
var _rpc: MatchCardRpc
var state: GameState = null
## Active uid whose temp GY was already flushed this turn (avoid re-flush).
var _flushed_turn_uid := ""


func setup(session: Node, shared_rpc: MatchCardRpc = null, connect_receive: bool = true) -> void:
	_session = session
	if shared_rpc != null:
		_rpc = shared_rpc
	else:
		_rpc = MatchCardRpc.new()
		_rpc.name = "MatchCardRpc"
		add_child(_rpc)
	if connect_receive:
		if not _rpc.card_snapshot_received.is_connected(_on_card_snapshot):
			_rpc.card_snapshot_received.connect(_on_card_snapshot)
		if not _rpc.cards_drawn_received.is_connected(_on_cards_drawn_rpc):
			_rpc.cards_drawn_received.connect(_on_cards_drawn_rpc)
		if not _rpc.play_requested.is_connected(handle_play_request):
			_rpc.play_requested.connect(handle_play_request)
		if not _rpc.pass_requested.is_connected(handle_pass_request):
			_rpc.pass_requested.connect(handle_pass_request)
	if not session.room_changed.is_connected(_on_room_changed):
		session.room_changed.connect(_on_room_changed)


func send_play_request(card_ids: Array) -> void:
	var uid := (
		PlayerDataStore.data.uid
		if PlayerDataStore.data != null
		else ""
	)
	_trace_play(
		"client.request",
		"uid=%s peer=%d ids=%s cards=%s %s" % [
			uid,
			multiplayer.get_unique_id(),
			JSON.stringify(card_ids),
			_describe_card_ids(card_ids),
			_match_context(),
		],
	)
	if _rpc == null:
		_trace_play("client.send_failed", "reason=rpc_missing ids=%s" % JSON.stringify(card_ids))
		return
	_rpc.send_play(card_ids)


func send_pass_request() -> void:
	if _rpc != null:
		_rpc.send_pass()


func handle_play_request(peer_id: int, card_ids: Array) -> void:
	if not _is_host():
		_trace_play(
			"server.reject",
			"reason=not_authority peer=%d ids=%s" % [peer_id, JSON.stringify(card_ids)],
		)
		return
	var uid := _uid_for_peer(peer_id)
	_trace_play(
		"server.received",
		"peer=%d uid=%s ids=%s %s" % [
			peer_id, uid, JSON.stringify(card_ids), _match_context(),
		],
	)
	handle_play_for_uid(uid, card_ids, "peer=%d" % peer_id)


## Host-side play (player request or turn-timeout auto-lead).
func handle_play_for_uid(uid: String, card_ids: Array, source: String = "internal") -> void:
	if not _is_host():
		_trace_play("server.reject", "reason=not_authority source=%s uid=%s" % [source, uid])
		return
	var match_state := _match_state()
	if uid.is_empty():
		_trace_play(
			"server.reject",
			"reason=unresolved_uid source=%s ids=%s %s" % [
				source, JSON.stringify(card_ids), _match_context(),
			],
		)
		return
	if not _is_active_turn(uid, match_state):
		_trace_play(
			"server.reject",
			"reason=inactive_turn source=%s uid=%s ids=%s %s" % [
				source, uid, JSON.stringify(card_ids), _match_context(),
			],
		)
		return
	_ensure_initialized()
	if state == null:
		_trace_play("server.reject", "reason=card_state_missing source=%s uid=%s" % [source, uid])
		return
	var hand := state.get_player_hand(PlayerId.from_string(uid))
	if hand == null:
		_trace_play("server.reject", "reason=hand_missing source=%s uid=%s" % [source, uid])
		return
	var hand_before := _card_ids(hand.get_all_cards())
	var by_id: Dictionary = {}
	for card in hand.get_all_cards():
		by_id[card.instance_id.value] = card
	var selected: Array[Card] = []
	for raw in card_ids:
		var id := str(raw)
		if by_id.has(id) and not selected.has(by_id[id]):
			selected.append(by_id[id])
	if selected.is_empty():
		_trace_play(
			"server.reject",
			"reason=no_requested_cards_in_hand source=%s uid=%s requested=%s hand=%s" % [
				source, uid, JSON.stringify(card_ids), JSON.stringify(hand_before),
			],
		)
		return
	if not PlayCommit.apply(state, uid, selected):
		var validation := PlayValidator.evaluate(selected, state.current_trick_combo)
		_trace_play(
			"server.reject",
			"reason=play_commit_failed source=%s uid=%s requested=%s selected=%s combo=%s current_combo=%s validator_ok=%s" % [
				source,
				uid,
				JSON.stringify(card_ids),
				_describe_cards(selected),
				str(validation.get("combo")),
				str(state.current_trick_combo),
				str(validation.get("ok", false)),
			],
		)
		return
	_trace_play(
		"server.accept",
		"source=%s uid=%s requested=%s cards=%s hand_before=%s hand_after=%s combo=%s" % [
			source,
			uid,
			JSON.stringify(card_ids),
			_describe_cards(selected),
			JSON.stringify(hand_before),
			JSON.stringify(_card_ids(hand.get_all_cards())),
			str(state.current_trick_combo),
		],
	)
	_broadcast()
	_trace_play(
		"server.responded",
		"uid=%s result=accepted snapshot_broadcast=true %s" % [uid, _match_context()],
	)
	if _session.match_controller != null:
		if _session.match_controller.on_play_committed(uid):
			_session.match_controller.advance_turn(MatchController.TURN_GAP_SEC)


func handle_pass_request(peer_id: int) -> void:
	if not _is_host():
		return
	handle_pass_for_uid(_uid_for_peer(peer_id))


## Host-side pass (player request or empty-hand autoskip).
func handle_pass_for_uid(uid: String) -> void:
	if not _is_host():
		return
	var match_state := _match_state()
	if uid.is_empty() or not _is_active_turn(uid, match_state):
		return
	_ensure_initialized()
	if state == null:
		return
	# Trick winner must lead the new round unless they have no cards.
	if state.must_lead(uid):
		return
	state.passes_count += 1
	_broadcast()
	var order := match_state.order
	var next_uid := PlacementTracker.next_active_after(state, order, uid)
	if (
		TrickResolution.should_end_by_passes(state, order, next_uid)
		and _session.match_controller != null
	):
		_session.match_controller.end_round()
	elif _session.match_controller != null:
		_session.match_controller.advance_turn(MatchController.TURN_GAP_SEC)


## Host: client missed their turn countdown (+ grace). Pass, or auto-lead if required.
func handle_timeout_for_uid(uid: String) -> void:
	if not _is_host():
		return
	var match_state := _match_state()
	if uid.is_empty() or not _is_active_turn(uid, match_state):
		return
	_ensure_initialized()
	if state == null:
		return
	if state.must_lead(uid):
		var hand := state.get_player_hand(PlayerId.from_string(uid))
		if hand == null or hand.get_size() <= 0:
			return
		var card := hand.get_card(0)
		if card == null:
			return
		handle_play_for_uid(uid, [card.instance_id.value], "turn_timeout")
		return
	handle_pass_for_uid(uid)


func is_hand_empty(uid: String) -> bool:
	if state == null or uid.is_empty():
		return true
	var hand := state.get_player_hand(PlayerId.from_string(uid))
	return hand == null or hand.get_size() <= 0


func all_hands_empty() -> bool:
	if state == null or state.players.is_empty():
		return true
	for player in state.players:
		if player == null or player.hand == null:
			continue
		if player.hand.get_size() > 0:
			return false
	return true


func deck_size() -> int:
	if state == null or state.deck == null:
		return 0
	return state.deck.get_size()


func clear() -> void:
	state = null
	_flushed_turn_uid = ""
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
	# Clear the active seat's prior plays into the main graveyard once per turn.
	if MatchPhase.is_play_phase(phase) and not active_uid.is_empty():
		if active_uid != _flushed_turn_uid:
			_flushed_turn_uid = active_uid
			var moved := state.flush_player_temporary_graveyard(
				PlayerId.from_string(active_uid)
			)
			if not moved.is_empty():
				_broadcast()
	else:
		_flushed_turn_uid = ""


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
	if not ConnectionManager.is_server():
		if _session != null and _session.is_local_host() and RoomSession.match_rpc != null:
			RoomSession.match_rpc.send_host_command("draw_to_player", {"uid": uid, "count": count})
		return []
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


## Soft-fill each hand toward SoftDraw.TARGET, winner-first.
## Notifies every member (empty list when they drew nothing) so all clients show
## the round-end preview. Returns true when the soft-fill ran (preview should hold).
func draw_for_all_soft(target: int = SoftDraw.TARGET) -> bool:
	if not ConnectionManager.is_server():
		if _session != null and _session.is_local_host() and RoomSession.match_rpc != null:
			RoomSession.match_rpc.send_host_command("draw_for_all_soft", {"target": target})
		return false
	if not _is_host():
		return false
	_ensure_initialized()
	if state == null or state.deck == null:
		return false
	var match_state := _match_state()
	var order: PlayerOrder = match_state.order if match_state != null else null
	var drawn_by_uid := SoftDraw.apply(state, order, target)
	if not drawn_by_uid.is_empty():
		_broadcast()
	_notify_round_draws(drawn_by_uid)
	return true


## Tell each seat what they drew this soft-fill (may be empty).
func _notify_round_draws(drawn_by_uid: Dictionary) -> void:
	if _session == null or _session.current_room == null:
		return
	for member in _session.current_room.get_members():
		var moved: Array[Card] = []
		var raw: Variant = drawn_by_uid.get(member.uid, null)
		if raw is Array:
			for item in raw:
				if item is Card:
					moved.append(item)
		_notify_drawn(member.uid, moved)


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


## Host: wipe and rebuild deck+players from room DeckData with wild elevation.
func rebuild_match_deck() -> void:
	if not _is_host():
		return
	state = null
	_flushed_turn_uid = ""
	_ensure_initialized()


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
	var deck_data := _session.get_resolved_deck() as DeckData
	var deck := DeckWildBuilder.build(deck_data)
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
	var match_state := _session.match_controller.get_state() as MatchRuntimeState
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
	if _session == null or uid.is_empty():
		return
	var ids: Array[String] = []
	for card in moved:
		ids.append(card.instance_id.value)
	if _is_local_viewer(uid):
		_session.cards_drawn.emit(ids)
		return
	if _session.current_room == null or _rpc == null:
		return
	for member in _session.current_room.get_members():
		if member.uid == uid and member.peer_id > 0 and member.peer_id != multiplayer.get_unique_id():
			_rpc.send_cards_drawn_to(member.peer_id, ids)
			return


func _broadcast() -> void:
	if state == null or _session == null:
		return
	# Establish one authoritative card order before the host UI and snapshots
	# consume it. Clients must preserve this order, especially for hidden hands.
	state.sort_non_deck_holders()
	_emit_changed()
	if not _is_host() or _rpc == null or _session.current_room == null:
		return
	for member in _session.current_room.get_members():
		if member.peer_id <= 0:
			continue
		if _is_local_viewer(member.uid):
			continue
		_rpc.send_snapshot_to(member.peer_id, state.to_dict_for_viewer(member.uid))


func _is_local_viewer(uid: String) -> bool:
	if NetEnv.is_dedicated_server():
		return false
	return PlayerDataStore.data != null and PlayerDataStore.data.uid == uid


func _emit_changed() -> void:
	if _session != null:
		_session.card_state_changed.emit(state)


func _on_card_snapshot(snapshot: Dictionary) -> void:
	if _session != null and _session.is_leaving_voluntarily():
		return
	_trace_play(
		"client.snapshot_received",
		"players=%d phase=%s" % [
			(snapshot.get("players", []) as Array).size(),
			str(snapshot.get("currentPhase", "")),
		],
	)
	state = GameState.from_dict(snapshot)
	_hydrate_card_data_from_deck(state)
	var uid := (
		PlayerDataStore.data.uid
		if PlayerDataStore.data != null
		else ""
	)
	var hand: CardHolder = null
	if state != null and not uid.is_empty():
		hand = state.get_player_hand(PlayerId.from_string(uid))
	_trace_play(
		"client.snapshot_applied",
		"uid=%s hand=%s %s" % [
			uid,
			JSON.stringify(_card_ids(hand.get_all_cards()) if hand != null else []),
			_match_context(),
		],
	)
	_emit_changed()


## Client snapshots only carry cardId / rank / suit — restore portraits from the
## resolved room deck so hand / draw-preview views keep character visuals.
func _hydrate_card_data_from_deck(game_state: GameState) -> void:
	if game_state == null or _session == null:
		return
	var deck_data := _session.get_resolved_deck() as DeckData
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
			var was_wild := card.data.rank == CardEnums.Rank.WILD
			card.data = hydrated
			# Snapshot rank is authoritative. DeckData contains the printed
			# source rank, so only restore WILD when the server sent WILD.
			if was_wild:
				card.data.rank = CardEnums.Rank.WILD


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
	return ConnectionManager.is_server()


func _match_state() -> MatchRuntimeState:
	if _session == null or _session.match_controller == null:
		return null
	return _session.match_controller.get_state()


func _is_active_turn(uid: String, match_state: MatchRuntimeState) -> bool:
	if match_state == null or match_state.active_uid != uid:
		return false
	return MatchPhase.is_play_phase(match_state.phase)


func _uid_for_peer(peer_id: int) -> String:
	if _session == null or _session.current_room == null:
		return ""
	var room := _session.current_room as RoomData
	if room == null:
		return ""
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return ""
	var members := room.get_members()
	if idx >= members.size():
		return ""
	return members[idx].uid


func _trace_play(stage: String, details: String) -> void:
	print(
		"[MatchPlayTrace][%s][%.3f] %s" % [
			stage,
			Time.get_unix_time_from_system(),
			details,
		]
	)


func _match_context() -> String:
	var match_state := _match_state()
	var wild_name := (
		str(CardEnums.Rank.find_key(state.deck.wild_rank))
		if state != null and state.deck != null
		else "NONE"
	)
	if match_state == null:
		return "active_uid= phase=NO_MATCH_STATE wild_rank=%s" % wild_name
	return "active_uid=%s phase=%s wild_rank=%s" % [
		match_state.active_uid,
		MatchPhase.Phase.find_key(match_state.phase),
		wild_name,
	]


func _card_ids(cards: Array[Card]) -> Array[String]:
	var ids: Array[String] = []
	for card in cards:
		if card != null and card.instance_id != null:
			ids.append(card.instance_id.value)
	return ids


func _describe_card_ids(card_ids: Array) -> String:
	var cards: Array[Card] = []
	var unknown: Array[String] = []
	for raw_id in card_ids:
		var id := str(raw_id)
		var card := state.get_card_by_instance_id(id) if state != null else null
		if card != null:
			cards.append(card)
		else:
			unknown.append(id)
	return "%s unknown=%s" % [
		_describe_cards(cards),
		JSON.stringify(unknown),
	]


func _describe_cards(cards: Array[Card]) -> String:
	var descriptions: Array[Dictionary] = []
	for card in cards:
		if card == null:
			continue
		descriptions.append({
			"id": card.instance_id.value if card.instance_id != null else "",
			"card_id": card.data.cardId if card.data != null else "",
			"rank": CardEnums.Rank.find_key(card.rank),
			"suit": CardEnums.Suit.find_key(card.suit),
		})
	return JSON.stringify(descriptions)
