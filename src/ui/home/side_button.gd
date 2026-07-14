extends Button

@export var sizes: Vector2 = Vector2(48, 128)
@export var tween_duration: float = 0.4

enum _State { NORMAL, HOVERED, PRESSED }

var _state: _State = _State.NORMAL
var _touch_armed: bool = false
var _tween: Tween


func _ready() -> void:
	offset_transform_enabled = true
	custom_minimum_size.x = sizes.x
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	_set_hovered(false)


func _on_mouse_exited() -> void:
	if _touch_armed:
		return
	_set_normal()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _state == _State.PRESSED:
			return
		if not _touch_armed:
			# First touch: hover + expand, do not activate.
			_touch_armed = true
			_set_hovered(true)
			accept_event()


func _on_pressed() -> void:
	_touch_armed = false

func _set_normal() -> void:
	_state = _State.NORMAL
	_touch_armed = false
	_animate(sizes.x, 0.0)


func _set_hovered(_from_touch: bool) -> void:
	_state = _State.HOVERED
	_animate(sizes.y, 0.0)


func _animate(width: float, offset_x: float) -> void:
	if _tween != null:
		_tween.kill()
	if not is_inside_tree() or Engine.is_editor_hint():
		custom_minimum_size.x = width
		offset_transform_position.x = offset_x
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "custom_minimum_size:x", width, tween_duration)
	_tween.tween_property(self, "offset_transform_position:x", offset_x, tween_duration)
