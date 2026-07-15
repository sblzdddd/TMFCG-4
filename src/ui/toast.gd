extends CanvasLayer
## Global stacking toasts. Persist across scenes; content can be updated live.

const DEFAULT_DURATION := 3.0
const END_HINT_DURATION := 4.5
const ANIM_IN := 0.4
const ANIM_OUT := 0.28
const TOP_MARGIN := 20.0
const ITEM_SEP := 8.0
## Max toast body width before wrapping. Panels shrink to content below this.
const MAX_WIDTH := 560.0
const H_PAD := 18.0
const V_PAD := 10.0

var _root: Control
var _vbox: VBoxContainer
var _next_id := 1
## id -> { root: Control, label: Label, timer: SceneTreeTimer, tween: Tween }
var _entries: Dictionary = {}


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vbox = VBoxContainer.new()
	_vbox.name = "Stack"
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_vbox.add_theme_constant_override("separation", ITEM_SEP)
	# Full-width strip so SIZE_SHRINK_CENTER children can measure naturally and center.
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_vbox.offset_top = TOP_MARGIN
	_vbox.offset_bottom = 400.0
	_root.add_child(_vbox)


## Push a toast. [param duration] <= 0 keeps it until [method dismiss]. Returns id.
func push(text: String, duration: float = DEFAULT_DURATION) -> int:
	var id := _next_id
	_next_id += 1

	var panel := _make_panel(text)
	_vbox.add_child(panel)
	_fit_label(panel.get_node("Margin/Label") as Label)
	panel.offset_transform_enabled = true
	# Hide until enter offset is resolved against absolute screen top (needs layout).
	panel.modulate.a = 0.0
	panel.offset_transform_position = Vector2.ZERO

	var label: Label = panel.get_node("Margin/Label")
	_entries[id] = {"root": panel, "label": label, "timer": null, "tween": null}
	_arm_timer(id, duration)
	_begin_enter.call_deferred(id)
	return id


func update(id: int, text: String, refresh_duration: float = -1.0) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	var label := entry["label"] as Label
	label.text = text
	_fit_label(label)
	if refresh_duration >= 0.0:
		_arm_timer(id, refresh_duration)


func dismiss(id: int) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	_entries.erase(id)
	var panel: Control = entry["root"]
	var prev: Tween = entry.get("tween")
	if prev != null and is_instance_valid(prev):
		prev.kill()

	var end_y := _absolute_offscreen_y(panel)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "offset_transform_position:y", end_y, ANIM_OUT)
	tween.tween_callback(panel.queue_free)


func clear() -> void:
	for id in _entries.keys():
		dismiss(int(id))


func _begin_enter(id: int) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	var panel: Control = entry["root"]
	panel.reset_size()
	var start_y := _absolute_offscreen_y(panel)
	panel.offset_transform_position.y = start_y
	panel.modulate.a = 1.0

	var prev: Tween = entry.get("tween")
	if prev != null and is_instance_valid(prev):
		prev.kill()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "offset_transform_position:y", 0.0, ANIM_IN)
	entry["tween"] = tween


## Relative offset that parks the panel fully above the viewport top edge.
func _absolute_offscreen_y(panel: Control) -> float:
	var top := panel.global_position.y
	var h := panel.size.y
	if h < 1.0:
		h = panel.get_combined_minimum_size().y
	if h < 1.0:
		h = 48.0
	return -(top + h)


func _arm_timer(id: int, duration: float) -> void:
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	entry["timer"] = null
	if duration <= 0.0:
		return
	var timer := get_tree().create_timer(duration, true, false, true)
	entry["timer"] = timer
	timer.timeout.connect(func() -> void:
		if _entries.has(id) and _entries[id].get("timer") == timer:
			dismiss(id)
	)


func _make_panel(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.92)
	style.set_corner_radius_all(8)
	style.content_margin_left = H_PAD
	style.content_margin_top = V_PAD
	style.content_margin_right = H_PAD
	style.content_margin_bottom = V_PAD
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1))
	margin.add_child(label)
	return panel


## Shrink-wrap to content; enable wrap only when text would exceed [constant MAX_WIDTH].
func _fit_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2.ZERO
	var natural := label.get_minimum_size()
	var max_text_w := MAX_WIDTH - H_PAD * 2.0
	if natural.x > max_text_w:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(max_text_w, 0.0)
	else:
		# Keep a stable content width so the panel doesn't collapse on layout passes.
		label.custom_minimum_size = Vector2(ceili(natural.x), 0.0)
