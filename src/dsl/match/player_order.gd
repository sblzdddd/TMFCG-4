class_name PlayerOrder
extends RefCounted
## Ordered ring of player uids. Index order is turn sequence; advance is +1 mod N.

var uids: Array[String] = []


func _init(p_uids: Array[String] = []) -> void:
	uids = p_uids.duplicate()


func size() -> int:
	return uids.size()


func is_empty() -> bool:
	return uids.is_empty()


func index_of(uid: String) -> int:
	return uids.find(uid)


func has(uid: String) -> bool:
	return index_of(uid) >= 0


func set_order(new_uids: Array[String]) -> void:
	uids.clear()
	var seen: Dictionary = {}
	for uid in new_uids:
		if uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		uids.append(uid)


## Move [param uid] by [param offset] slots in the ring (positive = later in order).
func move_player(uid: String, offset: int) -> void:
	var from := index_of(uid)
	if from < 0 or uids.size() < 2 or offset == 0:
		return
	var n := uids.size()
	var target := posmod(from + offset, n)
	if target == from:
		return
	var item := uids[from]
	uids.remove_at(from)
	# `target` is the desired index in the final ring of size n.
	uids.insert(target, item)


func reverse() -> void:
	uids.reverse()


func remove(uid: String) -> bool:
	var idx := index_of(uid)
	if idx < 0:
		return false
	uids.remove_at(idx)
	return true


## Keep order of existing uids that are still in [param member_uids]; append any new members.
func ensure_members(member_uids: Array[String]) -> void:
	var member_set: Dictionary = {}
	for uid in member_uids:
		if not uid.is_empty():
			member_set[uid] = true
	var kept: Array[String] = []
	for uid in uids:
		if member_set.has(uid):
			kept.append(uid)
			member_set.erase(uid)
	for uid in member_uids:
		if member_set.has(uid):
			kept.append(uid)
			member_set.erase(uid)
	uids = kept


func next_after(uid: String) -> String:
	if uids.is_empty():
		return ""
	var idx := index_of(uid)
	if idx < 0:
		return uids[0]
	return uids[(idx + 1) % uids.size()]


func random_uid() -> String:
	if uids.is_empty():
		return ""
	return uids[randi() % uids.size()]


func to_dict() -> Dictionary:
	return {"uids": uids.duplicate()}


static func from_dict(dict: Dictionary) -> PlayerOrder:
	var result := PlayerOrder.new()
	var raw: Variant = dict.get("uids", [])
	if raw is Array:
		var list: Array[String] = []
		for item in raw:
			list.append(str(item))
		result.set_order(list)
	return result
