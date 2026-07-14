@tool
extends MarginContainer
class_name EditorMain

@export var _files_panel: FilesPanelController
@export var _card_session: CardSession
#@export var _exit_button: Button
#@export var _exit_confirm_dialog: ConfirmationDialog


func _ready() -> void:
	_apply_window_scale()
	if _files_panel and _card_session:
		_files_panel.card_selected.connect(_card_session.select_card)
		_files_panel.selection_cleared.connect(_card_session.clear)
		_files_panel.resource_deleted.connect(_card_session.handle_resource_deleted)
		_card_session.bind_files_panel(_files_panel)


func _apply_window_scale() -> void:
	if Engine.is_embedded_in_editor():
		get_window().content_scale_factor = 1.15
	elif not Engine.is_editor_hint():
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().content_scale_factor = 1.25
