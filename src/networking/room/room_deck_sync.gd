class_name RoomDeckSync
extends Node
## Host-authoritative room deck selection, resolve, and .tres transfer.

signal deck_ready(deck: DeckData)

const MAX_DECK_RESEND := 2

var _session: Node
var _rpc: RoomDeckRpc

## Host-local path used to serve non-builtin .tres bytes.
var host_source_path: String = ""
var resolved_path: String = ""
var resolved_deck: DeckData = null

var _resend_attempts := 0
var _resolve_token := 0


func setup(session: Node, shared_rpc: RoomDeckRpc = null, connect_receive: bool = true) -> void:
	_session = session
	if shared_rpc != null:
		_rpc = shared_rpc
	else:
		_rpc = RoomDeckRpc.new()
		_rpc.name = "RoomDeckRpc"
		add_child(_rpc)
	if connect_receive:
		if not _rpc.deck_tres_requested.is_connected(_on_deck_tres_requested):
			_rpc.deck_tres_requested.connect(_on_deck_tres_requested)
		if not _rpc.deck_tres_delivered.is_connected(_on_deck_tres_delivered):
			_rpc.deck_tres_delivered.connect(_on_deck_tres_delivered)
	if not session.room_changed.is_connected(_on_room_changed):
		session.room_changed.connect(_on_room_changed)


func clear() -> void:
	host_source_path = ""
	_clear_resolved()


func get_resolved_deck() -> DeckData:
	return resolved_deck


func set_deck_from_path(path: String) -> void:
	if _session.current_room == null:
		return
	if not _session.is_local_host():
		return
	if path.is_empty():
		return
	var profile := RoomDeckProfile.from_deck_path(path)
	if profile.id.is_empty() and profile.name.is_empty() and profile.path.is_empty():
		push_warning("Cannot apply room deck: failed to load %s" % path)
		return
	if ConnectionManager.is_server():
		_apply_deck_profile(profile, path)
		return
	# Online logical host: push profile to dedicated server (builtin paths only for now).
	_rpc.send_set_deck(profile.to_dict())


func apply_deck_profile_from_peer(peer_id: int, profile_dict: Dictionary) -> void:
	if not ConnectionManager.is_server() or _session.current_room == null:
		return
	if _session.has_method("_is_host_peer"):
		pass
	var room: RoomData = _session.current_room
	var idx := room.find_member_peer(peer_id)
	if idx < 0:
		return
	var uid := str((room.members[idx] as Dictionary).get("uid", ""))
	if uid != room.host_uid:
		return
	var profile := RoomDeckProfile.from_dict(profile_dict)
	_apply_deck_profile(profile, profile.path if profile.builtin else "")


func _apply_deck_profile(profile: RoomDeckProfile, source_path: String) -> void:
	_session.current_room.deck = profile
	host_source_path = source_path
	_session.broadcast_and_advertise()


func bind_host_default_source() -> void:
	var room: RoomData = _session.current_room
	if room == null or room.deck == null:
		return
	if room.deck.builtin and not room.deck.path.is_empty():
		host_source_path = room.deck.path


func _on_room_changed(room: RoomData) -> void:
	if room == null:
		_clear_resolved()
		return
	resolve()


func resolve() -> void:
	var room: RoomData = _session.current_room
	if room == null or room.deck == null:
		_clear_resolved()
		return

	var profile: RoomDeckProfile = room.deck
	_resolve_token += 1
	var token := _resolve_token

	if profile.builtin:
		if profile.path.is_empty():
			_clear_resolved()
			return
		var builtin_deck := DeckDataStore.load_deck(profile.path)
		if token != _resolve_token:
			return
		_set_resolved(profile.path, builtin_deck)
		return

	if _session.is_local_host() and not host_source_path.is_empty():
		var host_deck := DeckDataStore.load_deck(host_source_path)
		if token != _resolve_token:
			return
		_set_resolved(host_source_path, host_deck)
		return

	var cached_path := DeckDataStore.find_by_checksum(profile.checksum)
	if not cached_path.is_empty():
		var cached_deck := DeckDataStore.load_deck(cached_path)
		if token != _resolve_token:
			return
		_set_resolved(cached_path, cached_deck)
		return

	_resend_attempts = 0
	_rpc.send_request_deck_tres()


func _on_deck_tres_requested(peer_id: int) -> void:
	handle_deck_tres_request(peer_id)


func handle_deck_tres_request(peer_id: int) -> void:
	if not ConnectionManager.is_server() or _session.current_room == null:
		return
	var profile: RoomDeckProfile = _session.current_room.deck
	if profile == null or profile.builtin:
		return
	if host_source_path.is_empty():
		push_warning("Host has no local deck path to transfer.")
		return
	var bytes := DeckDataStore.read_tres_bytes(host_source_path)
	if bytes.is_empty():
		push_warning("Failed to read deck tres for transfer: %s" % host_source_path)
		return
	var checksum := profile.checksum
	if checksum.is_empty():
		checksum = DeckDataStore.file_checksum(host_source_path)
	_rpc.send_deck_tres_to(peer_id, bytes, checksum)


func _on_deck_tres_delivered(bytes: PackedByteArray, checksum: String) -> void:
	var room: RoomData = _session.current_room
	if room == null or room.deck == null or room.deck.builtin:
		return
	var profile: RoomDeckProfile = room.deck
	if not checksum.is_empty() and not profile.checksum.is_empty() and checksum != profile.checksum:
		_request_resend("checksum mismatch")
		return

	var look_checksum := checksum if not checksum.is_empty() else profile.checksum
	var existing := DeckDataStore.find_by_checksum(look_checksum)
	if not existing.is_empty():
		_set_resolved(existing, DeckDataStore.load_deck(existing))
		return

	var temp_path := DeckDataStore.TRANSFER_TEMP_PATH
	var err := DeckDataStore.import_tres_bytes(bytes, temp_path)
	if err != OK:
		_request_resend("broken tres (%s)" % error_string(err))
		return

	var deck := DeckDataStore.load_deck(temp_path)
	if deck == null:
		_request_resend("failed to load transferred tres")
		return

	var dest_base := "%s_%s" % [
		ResourceFsUtils.sanitize_filename(profile.name),
		ResourceFsUtils.sanitize_filename(room.host_uid),
	]
	var dest_path := ResourceFsUtils.make_unique_path(ResConst.USER_DECKS_DIR, dest_base, "tres")
	err = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(dest_path),
	)
	if err != OK:
		err = DeckDataStore.import_tres_bytes(bytes, dest_path)
		if err != OK:
			_request_resend("failed to save transferred deck")
			return
		_remove_temp_deck()
	else:
		DeckDataStore.decks_changed.emit()

	_set_resolved(dest_path, DeckDataStore.load_deck(dest_path))


func _request_resend(reason: String) -> void:
	_resend_attempts += 1
	_remove_temp_deck()
	if _resend_attempts <= MAX_DECK_RESEND:
		push_warning("Room deck transfer failed (%s); requesting resend (%d/%d)." % [
			reason, _resend_attempts, MAX_DECK_RESEND,
		])
		_rpc.send_request_deck_tres()
	else:
		push_error("Room deck transfer failed after %d attempts: %s" % [MAX_DECK_RESEND, reason])


func _set_resolved(path: String, deck: DeckData) -> void:
	resolved_path = path
	resolved_deck = deck
	_resend_attempts = 0
	deck_ready.emit(deck)


func _clear_resolved() -> void:
	resolved_path = ""
	resolved_deck = null
	_resend_attempts = 0
	_resolve_token += 1
	deck_ready.emit(null)


func _remove_temp_deck() -> void:
	var global_temp := ProjectSettings.globalize_path(DeckDataStore.TRANSFER_TEMP_PATH)
	if FileAccess.file_exists(global_temp):
		DirAccess.remove_absolute(global_temp)
