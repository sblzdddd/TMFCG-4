class_name InstanceWindowLayout
extends RefCounted
## Shared multi-instance editor window title + quadrant placement.


static func parse_instance_id() -> int:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--instance-id="):
			return int(argument.split("=")[1])
	return 0


static func apply(window: Window, title_prefix: String) -> void:
	var instance_id := parse_instance_id()
	var screen_size := DisplayServer.screen_get_size()
	var player_name := ""
	if PlayerDataStore.data != null:
		player_name = str(PlayerDataStore.data.name)
	window.title = "%s - Instance %d (%s)" % [title_prefix, instance_id, player_name]
	match instance_id:
		2:
			window.position = Vector2i(screen_size.x / 2, 0)
		3:
			window.position = Vector2i(0, screen_size.y / 2)
		4:
			window.position = Vector2i(screen_size.x / 2, screen_size.y / 2)
		_:
			window.position = Vector2i(0, 0)
