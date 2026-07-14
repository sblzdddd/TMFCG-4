@tool
extends Control
class_name LabelLineEdit

const _LABEL_SCALE_IDLE := Vector2.ONE
const _LABEL_SCALE_ACTIVE := Vector2(0.6, 0.6)

@export var label_text: String = "Field Label":
	set(value):
		if label_text == value:
			return
		label_text = value
		_sync_label()

@export var label_settings: LabelSettings:
	set(value):
		if label_settings == value:
			return
		_disconnect_label_settings()
		label_settings = value
		_connect_label_settings()
		_sync_label()

@onready var label: Label = $LabelMargin/Label

func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event is InputEventMouseButton and event.is_pressed():
		if not get_global_rect().has_point(event.global_position):
			release_focus()
	elif event.is_action_pressed("ui_cancel"):
		release_focus()
		get_viewport().set_input_as_handled()

func _on_text_submitted(_new_text: String) -> void:
	release_focus()

func _ready() -> void:
	if not focus_entered.is_connected(_on_focus):
		focus_entered.connect(_on_focus)
	if not focus_exited.is_connected(_on_unfocus):
		focus_exited.connect(_on_unfocus)
	if has_signal("text_submitted") and not is_connected("text_submitted", _on_text_submitted):
		connect("text_submitted", _on_text_submitted)
	if has_signal("text_changed") and not is_connected("text_changed", _on_text_changed):
		connect("text_changed", _on_text_changed)
	_connect_label_settings()
	_sync_label()
	_sync_label_scale(false)


func _edit_text() -> String:
	return str(get("text"))


func set_text_content(value: String) -> void:
	set("text", value)
	_sync_label_scale(false)


func _has_content() -> bool:
	return not _edit_text().is_empty()


func _select_all() -> void:
	if has_method("select_all"):
		call_deferred("select_all")


func _deselect() -> void:
	if has_method("deselect"):
		call("deselect")


func _resolve_label() -> Label:
	if is_instance_valid(label):
		return label
	return get_node_or_null("LabelMargin/Label") as Label


func _connect_label_settings() -> void:
	if not is_instance_valid(label_settings) or _resolve_label() == null:
		return
	if not label_settings.changed.is_connected(_on_label_settings_changed):
		label_settings.changed.connect(_on_label_settings_changed)


func _disconnect_label_settings() -> void:
	if not is_instance_valid(label_settings):
		return
	if label_settings.changed.is_connected(_on_label_settings_changed):
		label_settings.changed.disconnect(_on_label_settings_changed)


func _on_label_settings_changed() -> void:
	_sync_label()


func _sync_label() -> void:
	var inner := _resolve_label()
	if inner == null:
		return
	inner.text = label_text
	inner.visible = not label_text.is_empty()
	if is_instance_valid(label_settings):
		inner.label_settings = label_settings


func _sync_label_scale(animate: bool) -> void:
	var inner := _resolve_label()
	if inner == null:
		return
	var target := _LABEL_SCALE_ACTIVE if (has_focus() or _has_content()) else _LABEL_SCALE_IDLE
	if not animate or not is_inside_tree() or Engine.is_editor_hint():
		inner.offset_transform_scale = target
		return
	var tween := create_tween()
	tween.tween_property(inner, "offset_transform_scale", target, 0.2)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _on_text_changed(_new_text = null) -> void:
	_sync_label_scale(false)


func _on_focus():
	_select_all()
	_sync_label_scale(true)


func _on_unfocus():
	_deselect()
	_sync_label_scale(true)
