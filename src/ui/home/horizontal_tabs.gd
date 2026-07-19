extends HSplitContainer
class_name HorizontalTabs

@export var tab_buttons: Array[Button] = []
@export var tabs: Array[Control] = []
@export var gap: int = 45
@export var expansion: int = 450
@export var tween_duration: float = 0.5

var _active := -1
var _tween: Tween
var open := false


func _ready() -> void:
	_active = len(split_offsets)
	split_offsets = _offsets_for(_active)
	for i in range(len(tab_buttons)):
		tab_buttons[i].button_up.connect(_on_tab_selection.bind(i))
		tabs[i].modulate = Color(1,1,1,0)


func set_open(should_open: bool) -> void:
	var panel_w := (split_offsets.size() + 1) * gap
	if should_open:
		panel_w += expansion
	if _tween == null:
		_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(self, "custom_minimum_size", Vector2(panel_w, 0), tween_duration)
	_tween.parallel().tween_property(tabs[_active], "modulate", Color(1, 1, 1, 1 if should_open else 0), tween_duration)
	open = should_open




func _on_tab_selection(index: int) -> void:
	_tween = TweenUtils.init_tween(self, _tween)
	if index == _active:
		set_open(not open)
		return
	var new_offsets := _offsets_for(index)
	_tween.tween_property(tabs[_active], "modulate", Color(1, 1, 1, 0), tween_duration)
	_tween.parallel().tween_property(tabs[index], "modulate", Color(1, 1, 1, 1), tween_duration)
	_active = index
	if open:
		_tween.parallel().tween_property(self, "split_offsets", new_offsets, tween_duration)
	else:
		set_open(true)
		split_offsets = new_offsets

func _offsets_for(index: int) -> PackedInt32Array:
	var splits_cnt := split_offsets.size()
	var exp_px := expansion
	var offsets := PackedInt32Array()
	offsets.resize(splits_cnt)
	for i in range(splits_cnt):
		var value := gap * (i + 1)
		if index < splits_cnt and i >= index:
			value += exp_px
		offsets[i] = value
	return offsets
