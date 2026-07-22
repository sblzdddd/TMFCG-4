class_name RoomStartButton
extends Button
## Host-only Start / rematch control.


func _ready() -> void:
	pressed.connect(_on_pressed)
	RoomSession.match_changed.connect(func(_s) -> void: _refresh())
	RoomSession.room_changed.connect(func(_r) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var host := RoomSession.is_local_host()
	var phase := MatchPhase.Phase.INITIALIZATION
	if RoomSession.match_controller != null:
		var state := RoomSession.match_controller.get_state()
		if state != null:
			phase = state.phase
	var can := host and MatchStartFlow.can_start(phase)
	visible = can
	disabled = not can
	text = "再来一局" if phase == MatchPhase.Phase.GAME_OVER else "开始游戏"


func _on_pressed() -> void:
	if not RoomSession.is_local_host():
		return
	if RoomSession.match_controller == null:
		push_warning("RoomStartButton: match_controller missing")
		return
	RoomSession.match_controller.start_game()
