extends HBoxContainer

@export var reveal_duration: float = 0.55
@export var editor_scene: PackedScene

@export var left_panel: HorizontalTabs
@export var right_panel: Control
@export var title_hint: RichTextLabel
@export var editor_button: Button

var title_hint_tween: Tween
var _revealed: bool = false
var _reveal_tween: Tween


func _ready() -> void:
	var screen_size := DisplayServer.screen_get_size()
	var instance_id := 0
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--instance-id="):
			instance_id = int(argument.split("=")[1])
	
	get_window().title = "TMFCG - Instance %d (%s)" % [instance_id, PlayerDataStore.data.name]
	if instance_id == 2:
		get_window().position = Vector2(screen_size.x / 2, 0)
	elif instance_id == 3:
		get_window().position = Vector2(0, screen_size.y / 2)
	elif instance_id == 4:
		get_window().position = Vector2(screen_size.x / 2, screen_size.y / 2)
	else:
		get_window().position = Vector2(0, 0)
	if editor_button:
		editor_button.pressed.connect(_on_editor_pressed)
	_begin_auto_reveal()
	if LevelLoader.has_transitioned:
		_begin_auto_reveal()


func _input(event: InputEvent) -> void:
	if _revealed:
		return
	if not _is_start_input(event):
		return
	_reveal_panels()
	get_viewport().set_input_as_handled()


func _is_start_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _begin_auto_reveal() -> void:
	# Returning from another scene: skip "press any key", open after overlay settles.
	set_process_input(false)
	if title_hint:
		title_hint.modulate.a = 0.0
	while LevelLoader.is_loading():
		await get_tree().process_frame
	_reveal_panels()


func _reveal_panels() -> void:
	if _revealed:
		return
	_revealed = true
	set_process_input(false)

	if title_hint_tween != null:
		title_hint_tween.kill()
	title_hint_tween = create_tween().set_parallel(true)
	title_hint_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	title_hint_tween.tween_property(title_hint, "modulate:a", 0.0, reveal_duration)
	title_hint_tween.tween_property(title_hint, "offset_transform_position:y", 20.0, reveal_duration)

	if _reveal_tween != null:
		_reveal_tween.kill()
	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(left_panel, "offset_transform_position:x", 0.0, reveal_duration)
	_reveal_tween.tween_property(right_panel, "offset_transform_position:x", 0.0, reveal_duration)
	_reveal_tween.tween_property(right_panel, "custom_minimum_size:x", 48.0, reveal_duration)
	left_panel.set_open(true)


func _on_editor_pressed() -> void:
	if not _revealed: return
	LevelLoader.load_level(editor_scene.resource_path)
