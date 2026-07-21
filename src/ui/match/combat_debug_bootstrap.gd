extends Control
## Editor-only: when combat.tscn is the entry scene (Run Current Scene / multi-instance),
## instance ≤1 hosts a private room; other instances join 127.0.0.1.

const HOST_ADDR := "127.0.0.1"
const JOIN_RETRY_DELAY_SEC := 0.5
const JOIN_ATTEMPT_WAIT_SEC := 1.25
const JOIN_MAX_ATTEMPTS := 20


func _ready() -> void:
	_apply_instance_window_layout()
	if not _should_auto_bootstrap():
		return
	# Own bootstrap; ignore stale last-room rejoin from prior sessions.
	PlayerDataStore.clear_last_room()
	if RoomSession.rejoin:
		RoomSession.rejoin.reset()
	_bootstrap.call_deferred()


func _should_auto_bootstrap() -> bool:
	if not OS.has_feature("editor"):
		return false
	# Only when combat is the launch scene, not after title → create/join.
	if LevelLoader.has_transitioned:
		return false
	if RoomSession.current_room != null or ConnectionManager.is_connected_peer():
		return false
	return true


func _bootstrap() -> void:
	if RoomSession.current_room != null or ConnectionManager.is_connected_peer():
		return
	PlayerDataStore.clear_last_room()
	if RoomSession.rejoin:
		RoomSession.rejoin.reset()

	var instance_id := _parse_instance_id()
	if instance_id <= 1:
		BusyBlocker.begin("Debug: 正在创建房间…")
		var err := RoomSession.create_room(false, 4, "Debug Room")
		if err == OK:
			return
		push_warning(
			"CombatDebugBootstrap: create_room failed (%s); joining localhost"
			% error_string(err)
		)
		if BusyBlocker.is_busy():
			BusyBlocker.end()
		await _join_localhost()
	else:
		# Let instance 1 bind the port first.
		await get_tree().create_timer(JOIN_RETRY_DELAY_SEC).timeout
		await _join_localhost()


func _join_localhost() -> void:
	for attempt in JOIN_MAX_ATTEMPTS:
		if not is_inside_tree():
			return
		if RoomSession.current_room != null:
			return
		if RoomSession.rejoin:
			RoomSession.rejoin.reset()
		if not BusyBlocker.is_busy():
			BusyBlocker.begin("Debug: 正在加入 localhost…")
		else:
			BusyBlocker.show_hint(
				"Debug: 正在加入 localhost… (%d/%d)" % [attempt + 1, JOIN_MAX_ATTEMPTS]
			)
		var err := RoomSession.join_room(HOST_ADDR, NetConst.GAME_PORT)
		if err != OK:
			await get_tree().create_timer(JOIN_RETRY_DELAY_SEC).timeout
			continue
		var deadline_msec := Time.get_ticks_msec() + int(JOIN_ATTEMPT_WAIT_SEC * 1000.0)
		while Time.get_ticks_msec() < deadline_msec:
			if RoomSession.current_room != null:
				return
			if not ConnectionManager.is_connected_peer():
				break
			await get_tree().process_frame
		if RoomSession.current_room != null:
			return
		ConnectionManager.leave()
		await get_tree().create_timer(JOIN_RETRY_DELAY_SEC).timeout
	if BusyBlocker.is_busy():
		BusyBlocker.end("Debug: 加入 localhost 失败")
	push_warning("CombatDebugBootstrap: failed to join localhost after retries")


func _apply_instance_window_layout() -> void:
	if not OS.has_feature("editor"):
		return
	var instance_id := _parse_instance_id()
	var screen_size := DisplayServer.screen_get_size()
	var player_name := ""
	if PlayerDataStore.data != null:
		player_name = PlayerDataStore.data.name
	get_window().title = "TMFCG Combat - Instance %d (%s)" % [instance_id, player_name]
	if instance_id == 2:
		get_window().position = Vector2i(screen_size.x / 2, 0)
	elif instance_id == 3:
		get_window().position = Vector2i(0, screen_size.y / 2)
	elif instance_id == 4:
		get_window().position = Vector2i(screen_size.x / 2, screen_size.y / 2)
	elif instance_id > 0:
		get_window().position = Vector2i(0, 0)


func _parse_instance_id() -> int:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--instance-id="):
			return int(argument.split("=")[1])
	return 0
