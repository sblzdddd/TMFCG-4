@tool
extends ThumbnailPickerDialog
class_name AvatarPickerDialog

signal avatar_selected(avatar_id: String)


func _emit_selection(payload: Variant) -> void:
	super._emit_selection(payload)
	avatar_selected.emit(str(payload))


func _collect_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for avatar_id in AvatarUtils.list_avatar_ids():
		var texture := AvatarUtils.load_texture(avatar_id)
		if texture == null:
			continue
		entries.append({
			"display_name": "",
			"filter_text": avatar_id,
			"icon": texture,
			"payload": avatar_id,
		})
	return entries


func _is_payload_allowed(payload: Variant) -> bool:
	var avatar_id := str(payload)
	if avatar_id.is_empty():
		return false
	if not ResourceLoader.exists(AvatarUtils.path_for_id(avatar_id)):
		push_warning("Avatar id not found: %s" % avatar_id)
		return false
	return true
