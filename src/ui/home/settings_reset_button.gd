extends Button
## Resets persisted app settings (server + display scale) to defaults.


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	SettingsDataStore.reset_to_defaults()
	NetworkModeService.apply_preferred_mode()
