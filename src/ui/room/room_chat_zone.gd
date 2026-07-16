class_name RoomChatZone
extends PanelContainer
## Combat lobby chat: send/receive and BBCode rendering.

const CHAT_MSG_PREFAB := preload("res://definitions/prefabs/pre_chat_msg.tscn")
const EMOJI_PICKER_PREFAB := preload("res://definitions/prefabs/pre_emoji_picker.tscn")
const MAX_CHAT_LENGTH := 120

@onready var msg_layout: VBoxContainer = %ChatMsgLayout
@onready var chat_input: TextEdit = %ChatInput
@onready var emoji_button: Button = %EmojiButton
@onready var send_button: Button = %SendMsgButton

var _scroll: ScrollContainer
var _emoji_picker: EmojiPicker


func _ready() -> void:
	_scroll = msg_layout.get_parent() as ScrollContainer
	_clear_placeholders()
	_emoji_picker = EMOJI_PICKER_PREFAB.instantiate() as EmojiPicker
	add_child(_emoji_picker)
	_emoji_picker.emoji_selected.connect(_insert_emoji_markup)
	send_button.pressed.connect(_send_current)
	emoji_button.pressed.connect(_on_emoji_button_pressed)
	chat_input.gui_input.connect(_on_chat_input_gui_input)
	ChatService.chat_received.connect(_on_chat_received)


func _clear_placeholders() -> void:
	for child in msg_layout.get_children():
		child.queue_free()


func _on_emoji_button_pressed() -> void:
	_emoji_picker.toggle_above(chat_input)


func _on_chat_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			if key.shift_pressed:
				return
			chat_input.accept_event()
			_send_current()


func _send_current() -> void:
	var text := chat_input.text.strip_edges()
	if text.is_empty():
		return
	if text.length() > MAX_CHAT_LENGTH:
		Toast.push("消息过长（最多 %d 字）" % MAX_CHAT_LENGTH)
		return
	ChatService.send_chat(text)
	chat_input.text = ""
	if _emoji_picker and _emoji_picker.visible:
		_emoji_picker.hide()


func _on_chat_received(payload: Dictionary) -> void:
	var content := str(payload.get("content", ""))
	if content.is_empty():
		return
	var row := CHAT_MSG_PREFAB.instantiate() as ChatMsg
	msg_layout.add_child(row)
	row.set_content(payload)
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _insert_emoji_markup(id: String) -> void:
	var markup := EmojiDataStore.markup_for(id)
	var caret := chat_input.get_caret_column()
	var line := chat_input.get_caret_line()
	var text := chat_input.text
	var abs_pos := _caret_to_abs(text, line, caret)
	var next := text.substr(0, abs_pos) + markup + text.substr(abs_pos)
	if next.length() > MAX_CHAT_LENGTH:
		Toast.push("消息过长（最多 %d 字）" % MAX_CHAT_LENGTH)
		return
	chat_input.text = next
	var new_abs := abs_pos + markup.length()
	var new_line_col := _abs_to_caret(next, new_abs)
	chat_input.set_caret_line(new_line_col.x)
	chat_input.set_caret_column(new_line_col.y)
	chat_input.grab_focus()


func _caret_to_abs(text: String, line: int, column: int) -> int:
	var lines := text.split("\n")
	var pos := 0
	for i in mini(line, lines.size()):
		if i < line:
			pos += lines[i].length() + 1
		else:
			pos += mini(column, lines[i].length())
	if line >= lines.size():
		return text.length()
	return pos


func _abs_to_caret(text: String, abs_pos: int) -> Vector2i:
	var clamped := clampi(abs_pos, 0, text.length())
	var before := text.substr(0, clamped)
	var lines := before.split("\n")
	var line := lines.size() - 1
	var col := lines[line].length() if line >= 0 else 0
	return Vector2i(line, col)
