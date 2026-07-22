class_name ChatMsg
extends HBoxContainer
## Single chat row: avatar, nickname, and BBCode message body.

const EMOJI_SIZE_INLINE := 32
const EMOJI_SIZE_SOLO := 64

@onready var _avatar: TextureRect = %ChatUserAvatar
@onready var _name_label: Label = %ChatUserName
@onready var _msg_box: PanelContainer = %ChatMsgBox
@onready var _msg_label: RichTextLabel = %ChatMsg


func set_content(payload: Dictionary) -> void:
	var avatar_id := str(payload.get("avatar_id", ""))
	if not avatar_id.is_empty():
		_avatar.texture = AvatarUtils.load_texture(avatar_id)
	var nickname := str(payload.get("nickname", "Player"))
	var uid := str(payload.get("uid", ""))
	var local_uid := ""
	if PlayerDataStore.data != null:
		local_uid = PlayerDataStore.data.uid
	_name_label.text = "%s (我)" % nickname if uid == local_uid and not uid.is_empty() else nickname
	var content := str(payload.get("content", ""))
	var solo := _is_solo_emoji(content)
	var emoji_size := EMOJI_SIZE_SOLO if solo else EMOJI_SIZE_INLINE
	_msg_label.text = _content_to_bbcode(content, int(emoji_size))
	if solo:
		_apply_solo_emoji_box()


func _is_solo_emoji(content: String) -> bool:
	var trimmed := content.strip_edges()
	if not trimmed.begins_with("[") or not trimmed.ends_with("]"):
		return false
	var id := trimmed.substr(1, trimmed.length() - 2)
	return EmojiDataStore.has_emoji(id) and trimmed == EmojiDataStore.markup_for(id)


func _apply_solo_emoji_box() -> void:
	var base := _msg_box.get_theme_stylebox("panel")
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
	_msg_box.add_theme_stylebox_override("panel", style)


func _content_to_bbcode(content: String, emoji_size: int) -> String:
	var regex := RegEx.new()
	regex.compile("\\[[^\\]]+\\]")	# e.g. [幻想乡的日常 第1弹_鼓掌]
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
