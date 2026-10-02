extends Node

## Thin scene-change helper that wraps [LoadingOverlay] slide-in / slide-out.

const TITLE_SCENE := "res://definitions/levels/title.tscn"
const ROOM_SCENE := "res://definitions/levels/room.tscn"
const DEDICATED_SERVER_SCENE := "res://definitions/levels/dedicated_server.tscn"

## True after at least one successful [method load_level] scene swap this session.
var has_transitioned: bool = false

var _is_loading := false
## True while a [method load_level] transition is in progress.
var is_loading: bool:
	get: return _is_loading


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func current_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""


func ensure_level(path: String) -> void:
	if current_path() != path:
		load_level(path)


func load_level(path: String) -> void:
	if _is_loading:
		return
	if path.is_empty():
		push_error("LevelLoader: empty scene path")
		return
	_is_loading = true
	await LoadingOverlay.slide_in()
	LoadingOverlay.hold_cover()

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("LevelLoader: failed to change scene to %s (%s)" % [path, error_string(err)])
		await LoadingOverlay.slide_out()
		_is_loading = false
		return

	has_transitioned = true

	# change_scene_to_file is deferred; wait until the new current_scene exists.
	await get_tree().process_frame
	while get_tree().current_scene == null:
		await get_tree().process_frame
	await get_tree().process_frame

	LoadingOverlay.hold_cover()
	await LoadingOverlay.slide_out()
	_is_loading = false
