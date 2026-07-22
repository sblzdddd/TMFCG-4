extends Node

## Thin scene-change helper that wraps [LoadingOverlay] slide-in / slide-out.

## True after at least one successful [method load_level] scene swap this session.
var has_transitioned: bool = false

var _loading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_loading() -> bool:
	return _loading


func load_level(path: String) -> void:
	if _loading:
		return
	if path.is_empty():
		push_error("LevelLoader: empty scene path")
		return
	_loading = true
	await LoadingOverlay.slide_in()
	LoadingOverlay.hold_cover()

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("LevelLoader: failed to change scene to %s (%s)" % [path, error_string(err)])
		await LoadingOverlay.slide_out()
		_loading = false
		return

	has_transitioned = true

	# change_scene_to_file is deferred; wait until the new current_scene exists.
	await get_tree().process_frame
	while get_tree().current_scene == null:
		await get_tree().process_frame
	await get_tree().process_frame

	LoadingOverlay.hold_cover()
	await LoadingOverlay.slide_out()
	_loading = false
