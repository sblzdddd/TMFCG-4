class_name CardPointerInteraction
extends RefCounted
## Pointer / touch input for a [CardBase]: hover, taps, and touch-drag signals.
## Separates emulate-mouse-from-touch duplicates (device == DEVICE_ID_EMULATION).

var _host: CardBase
var _info: CardInfoInteraction
var _hovering := false


var hovering: bool:
	get:
		return _hovering


func setup(host: CardBase, info: CardInfoInteraction) -> void:
	_host = host
	_info = info
	host.visual.mouse_entered.connect(_on_mouse_entered)
	host.visual.mouse_exited.connect(_on_mouse_exited)
	host.visual.gui_input.connect(_on_gui_input)


func refresh_mouse_filter() -> void:
	var visual := _host.visual
	if visual == null:
		return
	# Face-up cards must STOP so stacked normals occlude skills behind them.
	# Info popup is gated separately via CardInfoInteraction.
	# Deck grids use PASS so parent ScrollContainers can drag-scroll.
	var face_up := _host.is_face_up()
	var wants_hit := _host.interactable or face_up
	if not wants_hit:
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif _host.pass_scroll_input:
		visual.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		visual.mouse_filter = Control.MOUSE_FILTER_STOP
	var back := _host.back
	if back != null:
		back.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE if face_up else Control.MOUSE_FILTER_STOP
		)


func _on_mouse_entered() -> void:
	_hovering = true
	_host.on_pointer_hover_entered()


func _on_mouse_exited() -> void:
	_hovering = false
	_host.on_pointer_hover_exited()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func _handle_screen_drag(sd: InputEventScreenDrag) -> void:
	if not _info.touch_holding:
		return
	if _host.pass_scroll_input:
		_info.cancel_touch_hold()
		return
	_info.notify_touch_drag(sd.relative)
	var gpos := _host.visual.get_global_transform_with_canvas() * sd.position
	_host.on_pointer_touch_dragged(gpos)


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if not _info.touch_holding:
		return
	if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if _host.pass_scroll_input:
		_info.cancel_touch_hold()
		return
	if mm.device != InputEvent.DEVICE_ID_EMULATION:
		return
	# Emulated mouse is captured by the press target — paint via position, not hover.
	_info.notify_touch_drag(mm.relative)
	_host.on_pointer_touch_dragged(_host.visual.get_global_mouse_position())


func _handle_screen_touch(st: InputEventScreenTouch) -> void:
	# Emulated touch from mouse — MouseButton path owns the gesture.
	if st.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if st.pressed:
		_info.begin_touch_hold()
		_host.on_pointer_touch_started()
	else:
		var as_tap := _info.end_touch_hold() and _host.interactable
		_host.on_pointer_touch_ended(as_tap)
	if not _host.pass_scroll_input:
		_host.accept_event()


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# Emulated mouse from touch — ScreenTouch path owns press/hold.
	# Do not accept when pass_scroll_input so ScrollContainer can drag.
	if mb.device == InputEvent.DEVICE_ID_EMULATION:
		if not _host.pass_scroll_input:
			_host.accept_event()
		return
	# Defense if a real mouse event arrives mid-touch hold.
	if _info.touch_holding:
		if not _host.pass_scroll_input:
			_host.accept_event()
		return
	if mb.pressed and _host.interactable:
		_host.on_pointer_pressed(false)
		if not _host.pass_scroll_input:
			_host.accept_event()
