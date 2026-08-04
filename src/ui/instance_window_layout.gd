class_name InstanceWindowLayout
extends RefCounted
## Shared multi-instance editor window title + quadrant placement.


const _TOP_MARGIN := 40
const _CELL_PAD := 16


static func parse_instance_id() -> int:
	var args := OS.get_cmdline_args()
	for i in args.size():
		var argument := args[i]
		if argument.begins_with("--instance-id="):
			return int(argument.get_slice("=", 1))
		if argument == "--instance-id" and i + 1 < args.size():
			return int(args[i + 1])
	return 0


static func apply(window: Window, title_prefix: String) -> void:
	var instance_id := parse_instance_id()
	var player_name := ""
	if PlayerDataStore.data != null:
		player_name = str(PlayerDataStore.data.name)
	window.title = "%s - Instance %d (%s)" % [title_prefix, instance_id, player_name]
	# Screen metrics can be unset on the first frame (macOS Retina); place next frame.
	(func() -> void: _place_window(window, instance_id)).call_deferred()


static func _place_window(window: Window, instance_id: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		var screen_size := DisplayServer.screen_get_size(screen)
		usable = Rect2i(DisplayServer.screen_get_position(screen), screen_size)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return

	# 1..4 → TL, TR, BL, BR. 0 (no flag) stays top-left without resizing.
	var quadrant := 0
	if instance_id >= 1:
		quadrant = (instance_id - 1) % 4

	@warning_ignore("integer_division")
	var cell := Vector2i(usable.size.x / 2, usable.size.y / 2)
	var pos := usable.position
	match quadrant:
		1:
			pos += Vector2i(cell.x, _TOP_MARGIN)
		2:
			pos += Vector2i(0, cell.y)
		3:
			pos += Vector2i(cell.x, cell.y)
		_:
			pos += Vector2i(0, _TOP_MARGIN)

	if instance_id >= 1:
		var size := Vector2i(
			maxi(cell.x - _CELL_PAD, 640),
			maxi(cell.y - _TOP_MARGIN - _CELL_PAD, 360),
		)
		window.size = size
	window.position = pos
