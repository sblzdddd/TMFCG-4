class_name RoomStartButton
extends Button
## Host-only Start / rematch control. Shows a shared 5s Toast countdown on all peers.

var _toast_id := -1
## True while a countdown Toast is showing (covers dedicated-server hosts).
var _countdown_active := false


func _ready() -> void:
	pressed.connect(_on_pressed)
	RoomSession.match_changed.connect(func(_s) -> void: _refresh())
	RoomSession.room_changed.connect(_on_room_changed)
	_wire_countdown()
	_refresh()


func _wire_countdown() -> void:
	## Local listen-server host (not in member peer RPC fan-out).
	if RoomSession.match_controller != null:
		var ctrl: MatchController = RoomSession.match_controller
		if not ctrl.start_countdown_tick.is_connected(_on_start_countdown):
			ctrl.start_countdown_tick.connect(_on_start_countdown)
	## Remote peers (and logical host under dedicated server).
	if RoomSession.match_rpc != null:
		var rpc: MatchRpc = RoomSession.match_rpc
		if not rpc.start_countdown_received.is_connected(_on_start_countdown):
			rpc.start_countdown_received.connect(_on_start_countdown)


func _on_room_changed(_room: RoomData) -> void:
	if _room == null:
		_cancel_toast()
	_refresh()


func _refresh() -> void:
	var host := RoomSession.is_local_host()
	var phase := MatchPhase.Phase.INITIALIZATION
	var counting := _countdown_active
	if RoomSession.match_controller != null:
		var state := RoomSession.match_controller.get_state()
		if state != null:
			phase = state.phase
		counting = counting or RoomSession.match_controller.is_start_countdown_active()
	var can_phase := MatchStartFlow.can_start(phase)
	var can := host and can_phase and not counting
	visible = host and can_phase
	disabled = not can
	text = "再来一局" if phase == MatchPhase.Phase.GAME_OVER else "开始游戏"
	if not can_phase:
		_finish_toast()


func _on_pressed() -> void:
	if not RoomSession.is_local_host():
		return
	if RoomSession.match_controller == null:
		push_warning("RoomStartButton: match_controller missing")
		return
	if _countdown_active or RoomSession.match_controller.is_start_countdown_active():
		return
	RoomSession.match_controller.start_game()


func _on_start_countdown(seconds: int) -> void:
	if seconds <= 0:
		_cancel_toast()
		_refresh()
		return
	_countdown_active = true
	var text := "对局将在 %d 秒后开始" % seconds
	if _toast_id < 0:
		_toast_id = Toast.push(text, 0.0)
	else:
		Toast.update(_toast_id, text)
	_refresh()


func _finish_toast() -> void:
	_countdown_active = false
	if _toast_id < 0:
		return
	Toast.update(_toast_id, "对局开始", Toast.END_HINT_DURATION)
	_toast_id = -1


func _cancel_toast() -> void:
	_countdown_active = false
	if _toast_id < 0:
		return
	Toast.dismiss(_toast_id)
	_toast_id = -1
