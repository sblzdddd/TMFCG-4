@tool
extends HBoxContainer
class_name ValueEdit

signal value_changed(new_value: float)

@export var text: String = "Label":
	set(v):
		text = v
		_update_label()

@export var label_settings: LabelSettings:
	set(v):
		label_settings = v
		_update_label()

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		_apply_to_widgets()

@export var max_value: float = 1.0:
	set(v):
		max_value = v
		_apply_to_widgets()

@export var value: float = 0.0:
	set(v):
		var clamped := clampf(v, min_value, max_value)
		if is_equal_approx(_value, clamped):
			return
		_value = clamped
		_apply_to_widgets()
	get:
		return _value

@export var slider_step: float = 0.01:
	set(v):
		slider_step = v
		_apply_to_widgets()

@export var spinbox_step: float = 0.1:
	set(v):
		spinbox_step = v
		_apply_to_widgets()

@export var rounded: bool = false:
	set(v):
		rounded = v
		_apply_to_widgets()

var _value: float = 0.0
var _label: Label
var _slider: HSlider
var _spinbox: SpinBox
var _syncing := false


func _enter_tree() -> void:
	_ensure_nodes()


func _ready() -> void:
	_ensure_nodes()
	_update_label()
	_apply_to_widgets()
	_slider.value_changed.connect(_on_widget_changed)
	_spinbox.value_changed.connect(_on_widget_changed)


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


func _apply_to_widgets() -> void:
	if not is_instance_valid(_slider):
		return
	_syncing = true
	_value = clampf(_value, min_value, max_value)
	_slider.min_value = min_value
	_slider.max_value = max_value
	_slider.step = slider_step
	_slider.rounded = rounded
	_spinbox.min_value = min_value
	_spinbox.max_value = max_value
	_spinbox.step = 1.0 if rounded else spinbox_step
	_spinbox.rounded = rounded
	_slider.set_value_no_signal(_value)
	_spinbox.set_value_no_signal(_value)
	_syncing = false


func _on_widget_changed(new_value: float) -> void:
	if _syncing:
		return
	var clamped := clampf(new_value, min_value, max_value)
	if is_equal_approx(_value, clamped):
		return
	_value = clamped
	_syncing = true
	_slider.set_value_no_signal(_value)
	_spinbox.set_value_no_signal(_value)
	_syncing = false
	value_changed.emit(_value)
