class_name PlayerStatusController
extends Node
## Dark frame + turn styling for Left/Top/Right seat panels.
## Frames wrap the full seat layout (card + countdown + buffs).

const IDLE_SUBTITLE := Color(0.7, 0.7, 0.7, 1)
const ACTIVE_SUBTITLE := Color(1, 0.95, 0.75, 1)
const TWEEN_DUR := 0.25

@export_group("Panel Styles")
@export var panel_style_idle: StyleBoxFlat
@export var panel_style_active: StyleBoxFlat
@export var panel_style_lead: StyleBoxFlat
@export var panel_margins := Vector4(12, 12, 12, 12)

@onready var _left_frame: PanelContainer = %LeftPlayer
@onready var _top_frame: PanelContainer = %TopPlayerFrame
@onready var _right_frame: PanelContainer = %RightPlayer
@onready var _left_card: UiCardItem = %LeftPlayerCard
@onready var _top_card: UiCardItem = %TopPlayerCard
@onready var _right_card: UiCardItem = %RightPlayerCard

var _frame_styles: Dictionary = {} # PanelContainer -> StyleBoxFlat
var _tweens: Dictionary = {} # PanelContainer -> Tween


func _ready() -> void:
	for frame in [_left_frame, _top_frame, _right_frame]:
		_ensure_frame_style(frame)
	# After MatchSeatBinder so subtitle patches win over identity binds.
	RoomSession.room_changed.connect(func(_r) -> void: call_deferred("_refresh"))
	RoomSession.match_changed.connect(func(_s) -> void: call_deferred("_refresh"))
	RoomSession.card_state_changed.connect(func(_s) -> void: call_deferred("_refresh"))
	call_deferred("_refresh")


func _refresh() -> void:
	var room: RoomData = RoomSession.current_room
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if room == null or match_state == null or PlayerDataStore.data == null:
		_apply_seat(_left_frame, _left_card, "", false, false)
		_apply_seat(_top_frame, _top_card, "", false, false)
		_apply_seat(_right_frame, _right_card, "", false, false)
		return

	var members_by_uid: Dictionary = {}
	for member in room.get_members():
		members_by_uid[member.uid] = member

	var seats := SeatLayout.resolve(PlayerDataStore.data.uid, match_state.order)
	var highlight_uid := _highlight_uid(match_state)
	var leading := _is_leading(highlight_uid)

	_apply_bound(
		_left_frame, _left_card, str(seats.get("left", "")), members_by_uid, highlight_uid, leading
	)
	_apply_bound(
		_top_frame, _top_card, str(seats.get("top", "")), members_by_uid, highlight_uid, leading
	)
	_apply_bound(
		_right_frame, _right_card, str(seats.get("right", "")), members_by_uid, highlight_uid, leading
	)


func _apply_bound(
	frame: PanelContainer,
	card: UiCardItem,
	uid: String,
	members_by_uid: Dictionary,
	highlight_uid: String,
	leading: bool,
) -> void:
	if uid.is_empty() or not members_by_uid.has(uid):
		_apply_seat(frame, card, "", false, false)
		return
	var member: RoomMember = members_by_uid[uid] as RoomMember
	var active := uid == highlight_uid and not highlight_uid.is_empty()
	_apply_seat(frame, card, _subtitle_for(member, active, active and leading), active, active and leading)


func _apply_seat(
	frame: PanelContainer,
	card: UiCardItem,
	subtitle: String,
	active: bool,
	leading: bool,
) -> void:
	if frame != null and frame.visible:
		_tween_frame(frame, leading, active)
	if card == null or not is_instance_valid(card) or not card.is_visible_in_tree():
		return
	if card.entry != null and card.entry.subtitle != subtitle:
		card.entry.subtitle = subtitle
	_set_subtitle_color(card, active or leading)


func _subtitle_for(member: RoomMember, active: bool, leading: bool) -> String:
	if not member.is_online:
		return "离线"
	if leading:
		return "领先出牌"
	if active:
		return "行动中"
	return "在线"


func _highlight_uid(match_state: MatchRuntimeState) -> String:
	if match_state.phase == MatchPhase.Phase.INITIALIZATION:
		return ""
	var card_state: GameState = null
	if RoomSession.match_card_controller != null:
		card_state = RoomSession.match_card_controller.get_state()
	var awaiting_lead := card_state != null and card_state.is_awaiting_lead()
	var winner_uid := (
		card_state.trick_winner_id.value
		if card_state != null and card_state.trick_winner_id != null
		else ""
	)
	if match_state.phase == MatchPhase.Phase.ROUND_RESOLUTION and awaiting_lead:
		return winner_uid
	if MatchPhase.is_play_phase(match_state.phase) and not match_state.active_uid.is_empty():
		return match_state.active_uid
	return ""


func _is_leading(highlight_uid: String) -> bool:
	if highlight_uid.is_empty() or RoomSession.match_card_controller == null:
		return false
	var card_state := RoomSession.match_card_controller.get_state()
	return card_state != null and card_state.must_lead(highlight_uid)


func _ensure_frame_style(frame: PanelContainer) -> void:
	if frame == null:
		return
	var template := panel_style_idle if panel_style_idle != null else _default_idle_style()
	var style := template.duplicate() as StyleBoxFlat
	_apply_panel_margins(style)
	frame.add_theme_stylebox_override("panel", style)
	_frame_styles[frame] = style


func _apply_panel_margins(style: StyleBoxFlat) -> void:
	style.content_margin_left = panel_margins.x
	style.content_margin_top = panel_margins.y
	style.content_margin_right = panel_margins.z
	style.content_margin_bottom = panel_margins.w


func _target_panel_style(leading: bool, active: bool) -> StyleBoxFlat:
	if leading and panel_style_lead != null:
		return panel_style_lead
	if active and panel_style_active != null:
		return panel_style_active
	if panel_style_idle != null:
		return panel_style_idle
	return _default_idle_style()


func _tween_frame(frame: PanelContainer, leading: bool, active: bool) -> void:
	var style: StyleBoxFlat = _frame_styles.get(frame) as StyleBoxFlat
	if style == null:
		_ensure_frame_style(frame)
		style = _frame_styles.get(frame) as StyleBoxFlat
	if style == null:
		return
	var target := _target_panel_style(leading, active)
	var bg := target.bg_color
	var border := target.border_color
	if style.bg_color.is_equal_approx(bg) and style.border_color.is_equal_approx(border):
		return
	var tw: Tween = _tweens.get(frame) as Tween
	tw = TweenUtils.init_tween(frame, tw, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tweens[frame] = tw
	tw.set_parallel(true)
	tw.tween_property(style, "bg_color", bg, TWEEN_DUR)
	tw.tween_property(style, "border_color", border, TWEEN_DUR)


func _set_subtitle_color(card: UiCardItem, emphasize: bool) -> void:
	var label := card.get_node_or_null("%Subtitle") as Label
	if label == null:
		return
	label.add_theme_color_override(
		"font_color",
		ACTIVE_SUBTITLE if emphasize else IDLE_SUBTITLE,
	)


func _default_idle_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.82)
	style.border_color = Color(0.28, 0.28, 0.28, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
