class_name MatchSeatBinder
extends MarginContainer
## Binds Left/Top/Right player columns to match order relative to the local player.
## Top uses a fixed-width frame inside an expanding center column.

@onready var _left_seat: Control = %LeftPlayer
@onready var _right_seat: Control = %RightPlayer
@onready var _left_card: UiCardItem = %LeftPlayerCard
@onready var _top_card: UiCardItem = %TopPlayerCard
@onready var _right_card: UiCardItem = %RightPlayerCard
@onready var _top_frame: Control = %TopPlayerFrame


func _ready() -> void:
	# MatchOverlay sits above CardsLayer; layout chrome must not eat card clicks.
	_passthrough_mouse(self)
	RoomSession.room_changed.connect(_on_changed)
	RoomSession.match_changed.connect(_on_match_changed)
	_refresh()


func _passthrough_mouse(node: Node) -> void:
	if node is BaseButton or node is UiCardItem:
		return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_passthrough_mouse(child)


func _on_changed(_room: RoomData) -> void:
	_refresh()


func _on_match_changed(_state: MatchRuntimeState) -> void:
	_refresh()


func _refresh() -> void:
	var room: RoomData = RoomSession.current_room
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()

	if room == null or match_state == null or PlayerDataStore.data == null:
		_apply_seats({"left": "", "top": "", "right": ""}, {})
		return

	var members_by_uid: Dictionary = {}
	for member in room.get_members():
		members_by_uid[member.uid] = member

	var local_uid := PlayerDataStore.data.uid
	var seats := SeatLayout.resolve(local_uid, match_state.order)
	_apply_seats(seats, members_by_uid)


func _apply_seats(seats: Dictionary, members_by_uid: Dictionary) -> void:
	_bind_side_column(
		_left_seat,
		_left_card,
		str(seats.get("left", "")),
		members_by_uid,
	)
	_bind_side_column(
		_right_seat,
		_right_card,
		str(seats.get("right", "")),
		members_by_uid,
	)
	_bind_top_seat(str(seats.get("top", "")), members_by_uid)


func _bind_side_column(
	seat: Control,
	card: UiCardItem,
	uid: String,
	members_by_uid: Dictionary,
) -> void:
	if seat == null:
		return
	if uid.is_empty() or not members_by_uid.has(uid):
		seat.visible = false
		return
	seat.visible = true
	_apply_card(card, uid, members_by_uid)


func _bind_top_seat(uid: String, members_by_uid: Dictionary) -> void:
	var occupied := not uid.is_empty() and members_by_uid.has(uid)
	if _top_frame:
		_top_frame.visible = occupied
	if occupied:
		_apply_card(_top_card, uid, members_by_uid)


func _apply_card(card: UiCardItem, uid: String, members_by_uid: Dictionary) -> void:
	if card == null:
		return
	var member: RoomMember = members_by_uid[uid] as RoomMember
	var icon: Texture2D = null
	if not member.avatar_id.is_empty():
		icon = AvatarUtils.load_texture(member.avatar_id)
	var status := "" # [PlayerStatusController] owns turn / online subtitle.
	card.configure(UiCardEntry.new(
		member.uid,
		member.nickname,
		status,
		"",
		"",
		icon,
		false,
	))
