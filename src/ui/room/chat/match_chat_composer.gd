class_name MatchChatComposer
extends VBoxContainer
## MatchOverlay chat toggle: input, emoji picker, and send.

const EMOJI_PICKER_PREFAB := preload("res://definitions/prefabs/pre_emoji_picker.tscn")
const MAX_CHAT_LENGTH := 120

@onready var _toggle: Button = %MatchChatButton
@onready var _bar: Control = %MatchChatBar
@onready var _input: TextEdit = %MatchChatInput
@onready var _emoji_button: Button = %MatchChatEmojiButton
@onready var _send_button: Button = %MatchChatSendButton

var _emoji_picker: EmojiPicker


func _ready() -> void:
	_bar.visible = false
	_emoji_picker = EMOJI_PICKER_PREFAB.instantiate() as EmojiPicker
	# Keep out of VBox layout; PopupPanel is positioned globally.
	var host := get_parent()
	if host != null:
		host.add_child.call_deferred(_emoji_picker)
	else:
		add_child.call_deferred(_emoji_picker)
	_emoji_picker.emoji_selected.connect(_insert_emoji_markup)
	_toggle.toggled.connect(_on_toggle)
	_send_button.pressed.connect(_send_current)
	_emoji_button.pressed.connect(_on_emoji_button_pressed)
	_input.gui_input.connect(_on_chat_input_gui_input)


func _on_toggle(pressed: bool) -> void:
	_bar.visible = pressed
	if pressed:
		_input.grab_focus()
	elif _emoji_picker and _emoji_picker.visible:
		_emoji_picker.hide()


func _on_emoji_button_pressed() -> void:
	_emoji_picker.toggle_below(_input)


func _on_chat_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			if key.shift_pressed:
				return
			_input.accept_event()
			_send_current()


func _send_current() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty():
		return
	if text.length() > MAX_CHAT_LENGTH:
		Toast.push("消息过长（最多 %d 字）" % MAX_CHAT_LENGTH)
		return
	ChatService.send_chat(text)
	_input.text = ""
	if _emoji_picker and _emoji_picker.visible:
		_emoji_picker.hide()


func _insert_emoji_markup(id: String) -> void:
	var markup := EmojiDataStore.markup_for(id)
	var caret := _input.get_caret_column()
	var line := _input.get_caret_line()
	var text := _input.text
	var abs_pos := _caret_to_abs(text, line, caret)
	var next := text.substr(0, abs_pos) + markup + text.substr(abs_pos)
	if next.length() > MAX_CHAT_LENGTH:
		Toast.push("消息过长（最多 %d 字）" % MAX_CHAT_LENGTH)
		return
	_input.text = next
	var new_abs := abs_pos + markup.length()
	var new_line_col := _abs_to_caret(next, new_abs)
	_input.set_caret_line(new_line_col.x)
	_input.set_caret_column(new_line_col.y)
	_input.grab_focus()


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
