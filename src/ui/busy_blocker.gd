extends CanvasLayer
## Global busy gate + fullscreen mouse blocker. Status text goes through Toast.

signal actions_enabled_changed(enabled: bool)

var _busy := false
var _toast_id := -1
var _blocker: ColorRect


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_blocker = ColorRect.new()
	_blocker.name = "Blocker"
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.color = Color(0.05, 0.05, 0.05, 0.55)
	_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blocker.visible = false
	root.add_child(_blocker)

	RoomSession.join_failed.connect(_on_join_failed)
	RoomSession.room_changed.connect(_on_room_changed)

	end()


func is_busy() -> bool:
	return _busy


func begin(hint: String = "") -> bool:
	if _busy:
		return false
	_busy = true
	_set_blocker_visible(true)
	if not hint.is_empty():
		_toast_id = Toast.push(hint, 0.0)
	actions_enabled_changed.emit(false)
	return true


func end(hint: String = "") -> void:
	_busy = false
	_set_blocker_visible(false)
	# Morph the busy toast into the result hint, or hold the last busy text briefly.
	if not hint.is_empty():
		if _toast_id >= 0:
			Toast.update(_toast_id, hint, Toast.END_HINT_DURATION)
			_toast_id = -1
		else:
			Toast.push(hint, Toast.END_HINT_DURATION)
	elif _toast_id >= 0:
		Toast.hold(_toast_id, Toast.END_HINT_DURATION)
		_toast_id = -1
	actions_enabled_changed.emit(true)


## Update the sticky busy toast, or push a one-shot hint when idle.
func show_hint(text: String) -> void:
	if text.is_empty():
		return
	if _busy and _toast_id >= 0:
		Toast.update(_toast_id, text)
	elif _busy:
		_toast_id = Toast.push(text, 0.0)
	else:
		Toast.push(text)


func _set_blocker_visible(blocker_visible: bool) -> void:
	_blocker.visible = blocker_visible
	_blocker.mouse_filter = (
		Control.MOUSE_FILTER_STOP if blocker_visible else Control.MOUSE_FILTER_IGNORE
	)


func _on_join_failed(reason: String) -> void:
	push_warning("Join failed: %s" % reason)
	if _busy:
		end("连接失败: %s" % reason)
	else:
		Toast.push("连接失败: %s" % reason, Toast.END_HINT_DURATION)


func _on_room_changed(room: RoomData) -> void:
	# Lifecycle only: room ready means this busy gate is done.
	if room != null and _busy:
		end()
