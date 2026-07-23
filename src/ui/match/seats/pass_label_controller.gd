class_name PassLabelController
extends Node
## Pops Left/Top/Right "不要" labels when a seat passes; fades them out on that
## seat's next turn (same lifetime as temporary graveyard cards).

const POP_DUR := 0.28
const POP_SCALE := 0.55

@onready var _left: Label = %LeftPassLabel
@onready var _top: Label = %TopPassLabel
@onready var _right: Label = %RightPassLabel

var _visible_for: Dictionary = {} # Label -> bool
var _tweens: Dictionary = {} # Label -> Tween


func _ready() -> void:
	for label in [_left, _top, _right]:
		if label == null:
			continue
		label.offset_transform_enabled = true
		_reset_hidden(label)
	RoomSession.card_state_changed.connect(func(_s) -> void: _refresh())
	RoomSession.match_changed.connect(func(_s) -> void: _refresh())
	RoomSession.room_changed.connect(func(_r) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var want := {"left": false, "top": false, "right": false}
	var card_state: GameState = null
	if RoomSession.match_card_controller != null:
		card_state = RoomSession.match_card_controller.get_state()
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if (
		card_state != null
		and match_state != null
		and PlayerDataStore.data != null
		and match_state.phase != MatchPhase.Phase.INITIALIZATION
		and match_state.phase != MatchPhase.Phase.GAME_OVER
	):
		var seats := SeatLayout.resolve(PlayerDataStore.data.uid, match_state.order)
		for key in ["left", "top", "right"]:
			var uid := str(seats.get(key, ""))
			want[key] = card_state.has_passed(uid)

	_set_label(_left, bool(want["left"]))
	_set_label(_top, bool(want["top"]))
	_set_label(_right, bool(want["right"]))


func _set_label(label: Label, show: bool) -> void:
	if label == null:
		return
	var was := bool(_visible_for.get(label, false))
	if show == was:
		return
	_visible_for[label] = show
	if show:
		_pop_in(label)
	else:
		_fade_out(label)


func _pop_in(label: Label) -> void:
	label.visible = true
	label.modulate.a = 0.0
	label.offset_transform_scale = Vector2(POP_SCALE, POP_SCALE)
	var tw := TweenUtils.init_tween(label, _tweens.get(label) as Tween, Tween.TRANS_BACK, Tween.EASE_OUT)
	_tweens[label] = tw
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 1.0, POP_DUR)
	tw.tween_property(label, "offset_transform_scale", Vector2.ONE, POP_DUR)


func _fade_out(label: Label) -> void:
	var tw := CardAnim.init_fade_out_tween(label, _tweens.get(label) as Tween)
	_tweens[label] = tw
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 0.0, CardAnim.fade_out_duration())
	tw.tween_property(label, "offset_transform_scale", Vector2(POP_SCALE, POP_SCALE), CardAnim.fade_out_duration())
	tw.chain().tween_callback(func() -> void:
		if not bool(_visible_for.get(label, false)):
			_reset_hidden(label)
	)


func _reset_hidden(label: Label) -> void:
	label.modulate.a = 0.0
	label.offset_transform_scale = Vector2(POP_SCALE, POP_SCALE)
	label.visible = false
	_visible_for[label] = false
