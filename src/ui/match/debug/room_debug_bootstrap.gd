extends Control
## Editor-only: when room.tscn is the entry scene (Run Current Scene / multi-instance),
## ensure a dedicated server (remote or local spawn), then lobby create/join.

const CODE_FILE := "user://tmfcg/debug_room_code.txt"
const JOIN_RETRY_DELAY_SEC := 0.5
const JOIN_MAX_ATTEMPTS := 40
const ROOM_WAIT_SEC := 10.0


func _ready() -> void:
	InstanceWindowLayout.apply(get_window(), "TMFCG Room")
	if not _should_auto_bootstrap():
		return
	PlayerDataStore.clear_last_room()
	if RoomSession.rejoin:
		RoomSession.rejoin.reset()
	_bootstrap.call_deferred()


func _should_auto_bootstrap() -> bool:
	if not OS.has_feature("editor"):
		return false
	# Only when room is the launch scene, not after title → create/join.
	if LevelLoader.has_transitioned:
		return false
	if RoomSession.current_room != null:
		return false
	return true


func _bootstrap() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if RoomSession.current_room != null:
		return
	PlayerDataStore.clear_last_room()
	if RoomSession.rejoin:
		RoomSession.rejoin.reset()

	BusyBlocker.begin("Debug: 正在连接服务器…")
	if not await NetworkModeService.ensure_central_async():
		if BusyBlocker.is_busy():
			BusyBlocker.end("Debug: 无法连接服务器")
		push_warning("RoomDebugBootstrap: central connect failed")
		return

	var instance_id := InstanceWindowLayout.parse_instance_id()
	if instance_id <= 1:
		await _create_debug_room()
	else:
		if not await _safe_wait(JOIN_RETRY_DELAY_SEC):
			return
		await _join_debug_room()


func _create_debug_room() -> void:
	_clear_code_file()
	BusyBlocker.show_hint("Debug: 正在创建房间…")
	var err := RoomSession.create_room(false, 4, "Debug Room")
	if err != OK:
		if BusyBlocker.is_busy():
			BusyBlocker.end("Debug: 创建失败 (%s)" % error_string(err))
		push_warning("RoomDebugBootstrap: create_room failed (%s)" % error_string(err))
		return
	var deadline_msec := Time.get_ticks_msec() + int(ROOM_WAIT_SEC * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		if not is_inside_tree() or get_tree() == null:
			return
		if RoomSession.current_room != null and not RoomSession.current_room.code.is_empty():
			_write_code_file(RoomSession.current_room.code)
			if BusyBlocker.is_busy():
				BusyBlocker.end()
			return
		await get_tree().process_frame
	if BusyBlocker.is_busy():
		BusyBlocker.end("Debug: 创建房间超时")
	push_warning("RoomDebugBootstrap: create_room timed out waiting for snapshot")


func _join_debug_room() -> void:
	for attempt in JOIN_MAX_ATTEMPTS:
		if not is_inside_tree() or get_tree() == null:
			return
		if RoomSession.current_room != null:
			return
		if not NetworkModeService.is_central_connected():
			BusyBlocker.show_hint("Debug: 正在连接服务器…")
			if not await NetworkModeService.ensure_central_async():
				if not await _safe_wait(JOIN_RETRY_DELAY_SEC):
					return
				continue
		var code := _read_code_file()
		if code.is_empty():
			if not BusyBlocker.is_busy():
				BusyBlocker.begin("Debug: 等待主机房间代码…")
			else:
				BusyBlocker.show_hint(
					"Debug: 等待主机房间代码… (%d/%d)" % [attempt + 1, JOIN_MAX_ATTEMPTS]
				)
			if not await _safe_wait(JOIN_RETRY_DELAY_SEC):
				return
			continue
		if not BusyBlocker.is_busy():
			BusyBlocker.begin("Debug: 正在加入 %s…" % code)
		else:
			BusyBlocker.show_hint(
				"Debug: 正在加入 %s… (%d/%d)" % [code, attempt + 1, JOIN_MAX_ATTEMPTS]
			)
		var err := RoomSession.join_room_code(code)
		if err != OK:
			if not await _safe_wait(JOIN_RETRY_DELAY_SEC):
				return
			continue
		var deadline_msec := Time.get_ticks_msec() + int(ROOM_WAIT_SEC * 1000.0)
		while Time.get_ticks_msec() < deadline_msec:
			if not is_inside_tree() or get_tree() == null:
				return
			if RoomSession.current_room != null:
				if BusyBlocker.is_busy():
					BusyBlocker.end()
				return
			await get_tree().process_frame
		if RoomSession.current_room != null:
			return
		if not await _safe_wait(JOIN_RETRY_DELAY_SEC):
			return
	if BusyBlocker.is_busy():
		BusyBlocker.end("Debug: 加入失败")
	push_warning("RoomDebugBootstrap: failed to join debug room after retries")


func _clear_code_file() -> void:
	ResourceFsUtils.ensure_directories()
	if FileAccess.file_exists(CODE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CODE_FILE))


func _write_code_file(code: String) -> void:
	ResourceFsUtils.ensure_directories()
	var f := FileAccess.open(CODE_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("RoomDebugBootstrap: cannot write %s" % CODE_FILE)
		return
	f.store_string(code.strip_edges().to_upper())
	f.close()


func _read_code_file() -> String:
	if not FileAccess.file_exists(CODE_FILE):
		return ""
	var f := FileAccess.open(CODE_FILE, FileAccess.READ)
	if f == null:
		return ""
	var code := f.get_as_text().strip_edges().to_upper()
	f.close()
	return code


func _safe_wait(sec: float) -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	await tree.create_timer(sec).timeout
	return is_inside_tree() and get_tree() != null
