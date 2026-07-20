extends CanvasLayer

@onready var hide_button := %HideButton
@onready var show_button := %ShowSidebarButton
@onready var left_panels := %LeftPanels
@onready var right_panels := %RightPanels
@onready var sidebar_bg := %SidebarBG
@onready var settings_panel := %SettingsPanel
@onready var game_settings_toggle := %GameSettingsToggle

var _tween: Tween

func _ready() -> void:
	hide_button.pressed.connect(hide_sidebar)
	show_button.pressed.connect(show_sidebar)
	left_panels.offset_transform_enabled = true
	right_panels.offset_transform_enabled = true

func hide_sidebar() -> void:
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(left_panels, "offset_transform_position_ratio:x", -1.05, 0.45)
	_tween.parallel().tween_property(right_panels, "offset_transform_position_ratio:x", 1.05, 0.45)
	_tween.parallel().tween_property(sidebar_bg, "modulate:a", 0, 0.45)
	_tween.tween_callback(func(): visible = false)
	if game_settings_toggle.button_pressed:
		settings_panel.toggle_game_settings(false)

func show_sidebar() -> void:
	visible = true
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(left_panels, "offset_transform_position_ratio:x", 0, 0.45)
	_tween.parallel().tween_property(right_panels, "offset_transform_position_ratio:x", 0, 0.45)
	_tween.parallel().tween_property(sidebar_bg, "modulate:a", 1, 0.45)
	settings_panel.toggle_game_settings(game_settings_toggle.button_pressed)
