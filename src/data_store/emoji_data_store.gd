extends Node
## Scans res://assets/textures/emoji/ for [(category)_(name)].png stickers.

const EMOJI_DIR := "res://assets/textures/emoji/"

var categories: Array[String] = []
## category -> Array[{id, name, path, texture}]
var by_category: Dictionary = {}
## id (e.g. "夜雀食堂_疑惑") -> entry dict
var _by_id: Dictionary = {}


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	categories.clear()
	by_category.clear()
	_by_id.clear()
	for path in ResourceFsUtils.list_files(EMOJI_DIR, "png"):
		var stem := path.get_file().get_basename()
		if not stem.begins_with("[") or not stem.ends_with("]"):
			continue
		var inner := stem.substr(1, stem.length() - 2)
		var sep := inner.find("_")
		if sep < 0:
			continue
		var category := inner.substr(0, sep)
		var emoji_name := inner.substr(sep + 1)
		if category.is_empty() or emoji_name.is_empty():
			continue
		var id := inner
		var texture := ResourceFsUtils.load_texture(path)
		var entry := {
			"id": id,
			"name": emoji_name,
			"path": path,
			"texture": texture,
		}
		if not by_category.has(category):
			by_category[category] = [] as Array
			categories.append(category)
		(by_category[category] as Array).append(entry)
		_by_id[id] = entry


func get_categories() -> Array[String]:
	return categories


func get_emojis(category: String) -> Array:
	return by_category.get(category, []) as Array


func has_emoji(id: String) -> bool:
	return _by_id.has(id)


func get_texture(id: String) -> Texture2D:
	var entry: Variant = _by_id.get(id)
	if entry == null or not (entry is Dictionary):
		return null
	return (entry as Dictionary).get("texture") as Texture2D


func path_for(id: String) -> String:
	var entry: Variant = _by_id.get(id)
	if entry == null or not (entry is Dictionary):
		return ""
	return str((entry as Dictionary).get("path", ""))


func resource_ref(id: String) -> String:
	var path := path_for(id)
	if path.is_empty():
		return ""
	var uid := ResourceLoader.get_resource_uid(path)
	if uid != ResourceUID.INVALID_ID:
		return ResourceUID.id_to_text(uid)
	return path


func to_bbcode(id: String, size: int) -> String:
	var ref := resource_ref(id)
	if ref.is_empty():
		return ""
	return "[img width=%d height=%d valign=bottom]%s[/img]" % [size, size, ref]


func markup_for(id: String) -> String:
	return "[%s]" % id
