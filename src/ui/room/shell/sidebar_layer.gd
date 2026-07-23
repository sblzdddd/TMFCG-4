extends CanvasLayer

@onready var hide_button := %HideButton
@onready var show_button := %ShowSidebarButton
@onready var left_panels := %LeftPanels
@onready var right_panels := %RightPanels
@onready var sidebar_bg := %SidebarBG
@onready var room_settings_zone := %RoomSettingsZone
@onready var game_settings_toggle := %GameSettingsToggle

var _tween: Tween
var _last_phase: MatchPhase.Phase = MatchPhase.Phase.INITIALIZATION

func _ready() -> void:
	visible = true
	hide_button.pressed.connect(hide_sidebar)
	show_button.pressed.connect(show_sidebar)
	left_panels.offset_transform_enabled = true
	right_panels.offset_transform_enabled = true
	RoomSession.match_changed.connect(_on_match_changed)
	if RoomSession.match_controller != null:
		var state := RoomSession.match_controller.get_state()
		if state != null:
			_last_phase = state.phase

func _on_match_changed(state: MatchRuntimeState) -> void:
	if state == null:
		return
	var prev := _last_phase
	var next := state.phase
	_last_phase = next
	# Host start / remote start snapshot: leave lobby chrome.
	if (
		(prev == MatchPhase.Phase.INITIALIZATION or prev == MatchPhase.Phase.GAME_OVER)
		and next != MatchPhase.Phase.INITIALIZATION
		and next != MatchPhase.Phase.GAME_OVER
	):
		hide_sidebar()
		return
	# Rematch controls live in the sidebar.
	if next == MatchPhase.Phase.GAME_OVER and not visible:
		show_sidebar()

func hide_sidebar() -> void:
	if not visible and sidebar_bg.modulate.a <= 0.01:
		return
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(left_panels, "offset_transform_position_ratio:x", -1.05, 0.45)
	_tween.parallel().tween_property(right_panels, "offset_transform_position_ratio:x", 1.05, 0.45)
	_tween.parallel().tween_property(sidebar_bg, "modulate:a", 0, 0.45)
	_tween.tween_callback(func(): visible = false)
	if game_settings_toggle.button_pressed:
		room_settings_zone.toggle_game_settings(false)

func show_sidebar() -> void:
	visible = true
	sidebar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = TweenUtils.init_tween(self, _tween)
	_tween.tween_property(left_panels, "offset_transform_position_ratio:x", 0, 0.45)
	_tween.parallel().tween_property(right_panels, "offset_transform_position_ratio:x", 0, 0.45)
	_tween.parallel().tween_property(sidebar_bg, "modulate:a", 1, 0.45)
	room_settings_zone.toggle_game_settings(game_settings_toggle.button_pressed)
