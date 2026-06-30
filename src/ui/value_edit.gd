@tool
extends HBoxContainer

signal value_changed(new_value: float)

@export var text: String = "":
	set(new_text):
		text = new_text
		_update_label()

@export var label_settings: LabelSettings:
	set(new_settings):
		label_settings = new_settings
		_update_label()

@export var min_value: float = 0.0:
	set(new_min):
		min_value = new_min
		_apply_range()

@export var max_value: float = 1.0:
	set(new_max):
		max_value = new_max
		_apply_range()

@export var value: float = 0.0:
	set(new_value):
		var clamped := clampf(new_value, min_value, max_value)
		if is_equal_approx(_value, clamped):
			return
		_value = clamped
		_sync_widgets()
	get:
		return _value

@export var slider_step: float = 0.01:
	set(new_step):
		slider_step = new_step
		_apply_range()

@export var spinbox_step: float = 0.1:
	set(new_step):
		spinbox_step = new_step
		_apply_range()

@export var rounded: bool = false:
	set(new_rounded):
		rounded = new_rounded
		_apply_range()

var _value: float = 0.0
var _label: Label
var _slider: HSlider
var _spinbox: SpinBox
var _syncing := false


func _enter_tree() -> void:
	_ensure_nodes()


func _ready() -> void:
	_ensure_nodes()
	_slider.value_changed.connect(_on_slider_value_changed)
	_spinbox.value_changed.connect(_on_spinbox_value_changed)
	_update_label()
	_apply_range()
	_sync_widgets()


func _ensure_nodes() -> void:
	if is_instance_valid(_slider):
		return
	_label = $Label
	_slider = $HSlider
	_spinbox = $SpinBox


func _update_label() -> void:
	if not is_instance_valid(_label):
		return
	_label.text = text
	if label_settings:
		_label.label_settings = label_settings


func _apply_range() -> void:
	if not is_instance_valid(_slider):
		return
	_slider.min_value = min_value
	_slider.max_value = max_value
	_slider.step = slider_step
	_slider.rounded = rounded
	_spinbox.min_value = min_value
	_spinbox.max_value = max_value
	_spinbox.step = spinbox_step if not rounded else 1.0
	_spinbox.rounded = rounded
	_value = clampf(_value, min_value, max_value)
	_sync_widgets()


func _sync_widgets() -> void:
	if _syncing or not is_instance_valid(_slider):
		return
	_syncing = true
	_slider.set_value_no_signal(_value)
	_spinbox.set_value_no_signal(_value)
	_syncing = false


func _on_slider_value_changed(new_value: float) -> void:
	if _syncing:
		return
	_set_value(new_value)


func _on_spinbox_value_changed(new_value: float) -> void:
	if _syncing:
		return
	_set_value(new_value)


func _set_value(new_value: float) -> void:
	var clamped := clampf(new_value, min_value, max_value)
	if is_equal_approx(_value, clamped):
		return
	_value = clamped
	_sync_widgets()
	value_changed.emit(_value)
