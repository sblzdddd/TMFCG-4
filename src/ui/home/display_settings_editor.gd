extends GridContainer
class_name DisplaySettingsEditor
## Settings panel: display / UI scale options.

const SCALE_OPTIONS: Array[Dictionary] = [
	{"label": "50%", "value": 0.5},
	{"label": "60%", "value": 0.6},
	{"label": "75%", "value": 0.75},
	{"label": "80%", "value": 0.8},
	{"label": "90%", "value": 0.9},
	{"label": "100%", "value": 1.0},
	{"label": "110%", "value": 1.1},
	{"label": "125%", "value": 1.25},
	{"label": "130%", "value": 1.3},
	{"label": "150%", "value": 1.5},
	{"label": "175%", "value": 1.75},
	{"label": "200%", "value": 2.0},
]

@export var _scale_option: OptionButton

var _loading := false


func _ready() -> void:
	if _scale_option:
		_populate_scale_options()
		_scale_option.item_selected.connect(_on_scale_selected)
	SettingsDataStore.data_changed.connect(_on_store_changed)
	_apply_data(SettingsDataStore.data)


func _populate_scale_options() -> void:
	_scale_option.clear()
	for i in SCALE_OPTIONS.size():
		var option: Dictionary = SCALE_OPTIONS[i]
		_scale_option.add_item(str(option["label"]), i)


func _on_scale_selected(index: int) -> void:
	if _loading or index < 0 or index >= SCALE_OPTIONS.size():
		return
	SettingsDataStore.set_ui_base_scale(float(SCALE_OPTIONS[index]["value"]))


func _on_store_changed(data: SettingsData) -> void:
	_apply_data(data)


func _apply_data(data: SettingsData) -> void:
	if data == null or _scale_option == null:
		return
	_loading = true
	_scale_option.select(_nearest_scale_index(data.ui_base_scale))
	_loading = false


func _nearest_scale_index(scale: float) -> int:
	var best_index := 2
	var best_dist := INF
	for i in SCALE_OPTIONS.size():
		var dist := absf(float(SCALE_OPTIONS[i]["value"]) - scale)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index
