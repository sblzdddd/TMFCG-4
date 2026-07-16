class_name RoomChatZone
extends PanelContainer
## Combat lobby chat: send/receive and BBCode rendering.

const CHAT_MSG_PREFAB := preload("res://definitions/prefabs/pre_chat_msg.tscn")
const EMOJI_PICKER_PREFAB := preload("res://definitions/prefabs/pre_emoji_picker.tscn")
const MAX_CHAT_LENGTH := 120
const EMOJI_SIZE_INLINE := 32
const EMOJI_SIZE_SOLO := 64
const EMOJI_TOKEN_RE := "\\[[^\\]]+\\]"

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
	RoomManager.chat_received.connect(_on_chat_received)


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
	RoomManager.send_chat(text)
	chat_input.text = ""
	if _emoji_picker and _emoji_picker.visible:
		_emoji_picker.hide()


func _on_chat_received(payload: Dictionary) -> void:
	var content := str(payload.get("content", ""))
	if content.is_empty():
		return
	var row: Control = CHAT_MSG_PREFAB.instantiate()
	msg_layout.add_child(row)
	var avatar := row.get_node("%ChatUserAvatar") as TextureRect
	var name_label := row.get_node("%ChatUserName") as Label
	var msg_box := row.get_node("%ChatMsgBox") as PanelContainer
	var msg_label := row.get_node("%ChatMsg") as RichTextLabel
	var avatar_id := str(payload.get("avatar_id", ""))
	if avatar and not avatar_id.is_empty():
		avatar.texture = AvatarUtils.load_texture(avatar_id)
	var nickname := str(payload.get("nickname", "Player"))
	var uid := str(payload.get("uid", ""))
	var local_uid := ""
	if PlayerDataStore.data != null:
		local_uid = PlayerDataStore.data.uid
	if name_label:
		name_label.text = "%s (我)" % nickname if uid == local_uid and not uid.is_empty() else nickname
	var solo := _is_solo_emoji(content)
	var size := EMOJI_SIZE_SOLO if solo else EMOJI_SIZE_INLINE
	if msg_label:
		msg_label.text = _content_to_bbcode(content, size)
	if solo and msg_box:
		_apply_solo_emoji_box(msg_box)
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _is_solo_emoji(content: String) -> bool:
	var trimmed := content.strip_edges()
	if not trimmed.begins_with("[") or not trimmed.ends_with("]"):
		return false
	var id := trimmed.substr(1, trimmed.length() - 2)
	return EmojiDataStore.has_emoji(id) and trimmed == EmojiDataStore.markup_for(id)


func _apply_solo_emoji_box(msg_box: PanelContainer) -> void:
	var base := msg_box.get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if base is StyleBoxFlat:
		style = (base as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
	style.bg_color = Color(style.bg_color, 0.0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	msg_box.add_theme_stylebox_override("panel", style)


func _content_to_bbcode(content: String, emoji_size: int) -> String:
	var regex := RegEx.new()
	regex.compile(EMOJI_TOKEN_RE)
	var out := ""
	var pos := 0
	for m in regex.search_all(content):
		var start := m.get_start()
		var end := m.get_end()
		if start > pos:
			out += _escape_bbcode(content.substr(pos, start - pos))
		var token := m.get_string()
		var id := token.substr(1, token.length() - 2)
		if EmojiDataStore.has_emoji(id):
			out += EmojiDataStore.to_bbcode(id, emoji_size)
		else:
			out += _escape_bbcode(token)
		pos = end
	if pos < content.length():
		out += _escape_bbcode(content.substr(pos))
	return "[font_size=14]%s" % out


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


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
