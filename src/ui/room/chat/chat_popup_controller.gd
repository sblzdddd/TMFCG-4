class_name ChatPopupController
extends MarginContainer
## Top-right chat toast on MatchOverlay while the room sidebar is hidden.

const CHAT_MSG_PREFAB := preload("res://definitions/prefabs/pre_chat_msg.tscn")
const DISPLAY_SEC := 10.0

@onready var _sidebar: CanvasLayer = %SidebarLayer

var _row: ChatMsg
var _hide_token := 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = CHAT_MSG_PREFAB.instantiate() as ChatMsg
	_row.layout_mode = 2 # CONTAINER
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_row)
	_make_non_interactive(_row)
	ChatService.chat_received.connect(_on_chat_received)
	if _sidebar != null:
		_sidebar.visibility_changed.connect(_on_sidebar_visibility_changed)


func _on_chat_received(payload: Dictionary) -> void:
	if _sidebar == null or _sidebar.visible:
		return
	var content := str(payload.get("content", ""))
	if content.is_empty():
		return
	_row.set_content(payload)
	visible = true
	call_deferred("_fit_height")
	_arm_hide()


func _on_sidebar_visibility_changed() -> void:
	if _sidebar != null and _sidebar.visible:
		_dismiss()


func _arm_hide() -> void:
	_hide_token += 1
	var token := _hide_token
	await get_tree().create_timer(DISPLAY_SEC).timeout
	if token != _hide_token:
		return
	_dismiss()


func _dismiss() -> void:
	_hide_token += 1
	visible = false


func _fit_height() -> void:
	if _row == null or not visible:
		return
	var height := maxf(_row.get_combined_minimum_size().y, 48.0)
	offset_bottom = offset_top + height


func _make_non_interactive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_non_interactive(child)
