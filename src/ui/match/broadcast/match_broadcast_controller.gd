class_name MatchBroadcastController
extends Panel
## Plays BroadcastAnimation on phase changes (title + subtitle).

@onready var _anim: AnimationPlayer = %BroadcastAnimation
@onready var _title: Label = %BroadcastTitle
@onready var _subtitle: Label = %BroadcastSubtitle

var _last_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION
var _playing := false
var _pending: Dictionary = {}


func _ready() -> void:
	_reset_idle()
	RoomSession.match_changed.connect(_on_match_changed)
	if RoomSession.match_controller != null:
		var state := RoomSession.match_controller.get_state()
		if state != null:
			_last_phase = state.phase


func _reset_idle() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _title:
		_title.text = ""
	if _subtitle:
		_subtitle.text = ""
	if _anim and _anim.has_animation("RESET"):
		_anim.play("RESET")
		_anim.seek(0, true)
	# Collapsed off-screen like the start of broadcast_in.
	anchor_left = 1.0
	anchor_right = 1.0


func _on_match_changed(state: MatchRuntimeState) -> void:
	if state == null:
		return
	var prev := _last_phase
	var next := state.phase
	_last_phase = next
	if prev == next:
		return
	var copy := _copy_for_phase(prev, next)
	if copy.is_empty():
		return
	if _playing:
		_pending = copy
		return
	await play(str(copy.get("title", "")), str(copy.get("subtitle", "")))
	if not _pending.is_empty():
		var queued := _pending
		_pending = {}
		await play(str(queued.get("title", "")), str(queued.get("subtitle", "")))


func _copy_for_phase(prev: MatchPhase.Phase, next: MatchPhase.Phase) -> Dictionary:
	if next == MatchPhase.Phase.ROUND_RESOLUTION:
		if (
			prev == MatchPhase.Phase.INITIALIZATION
			or prev == MatchPhase.Phase.GAME_OVER
		):
			return {
				"title": "游戏开始",
				"subtitle": "万能牌: %s" % _wild_text(),
			}
		return {"title": "回合结算", "subtitle": "抽牌中…"}
	if next == MatchPhase.Phase.END_GAME_PLAY:
		return {"title": "终局阶段", "subtitle": "牌堆已空，率先出完者获胜"}
	if next == MatchPhase.Phase.GAME_OVER:
		return {"title": "游戏结束", "subtitle": _placement_subtitle()}
	return {}


func _wild_text() -> String:
	if RoomSession.match_card_controller == null:
		return "—"
	var gs := RoomSession.match_card_controller.get_state()
	if gs == null or gs.deck == null:
		return "—"
	return CardUtils.rank_display(gs.deck.wild_rank)


func _placement_subtitle() -> String:
	if RoomSession.match_card_controller == null or RoomSession.current_room == null:
		return ""
	var gs := RoomSession.match_card_controller.get_state()
	if gs == null:
		return ""
	var parts: PackedStringArray = []
	for i in gs.placements.size():
		var pid := gs.placements[i]
		if pid == null:
			continue
		var display_name := pid.value
		for member in RoomSession.current_room.get_members():
			if member.uid == pid.value:
				display_name = member.nickname if not member.nickname.is_empty() else pid.value
				break
		parts.append("%d. %s" % [i + 1, display_name])
	return " · ".join(parts)


func play(title: String, subtitle: String) -> void:
	if _title:
		_title.text = title
	if _subtitle:
		_subtitle.text = subtitle
	if _anim == null:
		return
	_playing = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim.play("broadcast_in")
	await _anim.animation_finished
	_playing = false
	_reset_idle()
