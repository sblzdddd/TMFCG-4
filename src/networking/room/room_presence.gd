class_name RoomPresence
extends Node
## Host-side offline grace timers for unexpected disconnects.

signal member_grace_expired(uid: String)

var _timers: Dictionary[String, SceneTreeTimer] = {}
var _pending_leave_uids: Dictionary[String, bool] = {}


func mark_voluntary_leave(uid: String) -> void:
	_pending_leave_uids[uid] = true
	cancel(uid)


func consume_voluntary_leave(uid: String) -> bool:
	if _pending_leave_uids.has(uid):
		_pending_leave_uids.erase(uid)
		return true
	return false


func mark_offline(uid: String) -> void:
	if uid.is_empty() or _pending_leave_uids.has(uid):
		return
	cancel(uid)
	var timer := get_tree().create_timer(NetConst.DISCONNECT_GRACE_SEC)
	_timers[uid] = timer
	timer.timeout.connect(_on_grace_timeout.bind(uid), CONNECT_ONE_SHOT)


func cancel(uid: String) -> void:
	if _timers.has(uid):
		_timers.erase(uid)


func clear_all() -> void:
	_timers.clear()
	_pending_leave_uids.clear()


func _on_grace_timeout(uid: String) -> void:
	if not _timers.has(uid):
		return
	_timers.erase(uid)
	member_grace_expired.emit(uid)
