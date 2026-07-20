class_name MatchDebugPanel
extends VBoxContainer
## Host-only mock controls for match order / phase.

@onready var _next_btn: Button = %DebugNextPlayer
@onready var _offset_btn: Button = %DebugOffsetPlayer
@onready var _reverse_btn: Button = %DebugReverseOrder
@onready var _end_round_btn: Button = %DebugEndRound
@onready var _end_game_btn: Button = %DebugEndGamePlay


func _ready() -> void:
	_next_btn.pressed.connect(_on_next)
	_offset_btn.pressed.connect(_on_offset)
	_reverse_btn.pressed.connect(_on_reverse)
	_end_round_btn.pressed.connect(_on_end_round)
	_end_game_btn.pressed.connect(_on_end_game)
	RoomSession.room_changed.connect(_on_room_changed)
	_refresh_visibility()


func _on_room_changed(_room: RoomData) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = RoomSession.is_local_host() and RoomSession.current_room != null


func _ctrl() -> MatchController:
	return RoomSession.match_controller


func _on_next() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.advance_turn()


func _on_offset() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.offset_active(1)


func _on_reverse() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.reverse_order()


func _on_end_round() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.end_round()


func _on_end_game() -> void:
	var ctrl := _ctrl()
	if ctrl:
		ctrl.end_game_play()
