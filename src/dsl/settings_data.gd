class_name SettingsData
extends Resource

## UI indices for DisplaySettingsEditor display-mode OptionButton.
const WINDOW_MODE_WINDOWED := 0
const WINDOW_MODE_BORDERLESS := 1
const WINDOW_MODE_EXCLUSIVE := 2

@export var server_address: String = "127.0.0.1"
@export var server_port: int = 13637
@export var ui_base_scale: float = 1.0
## 0 = windowed, 1 = borderless fullscreen, 2 = exclusive fullscreen.
@export var window_mode: int = WINDOW_MODE_WINDOWED
@export var window_width: int = 1280
@export var window_height: int = 720
## 0 = uncapped; otherwise Engine.max_fps.
@export var max_fps: int = 240
