@tool
extends MarginContainer
class_name EditorMain

const PHYSICAL_SCALE_MULT := 0.85

@export var _files_panel: FilesPanelController
@export var _card_session: CardSession
#@export var _exit_button: Button
#@export var _exit_confirm_dialog: ConfirmationDialog


func _ready() -> void:
	if not Engine.is_editor_hint():
		UiScale.physical_scale_multiplier = PHYSICAL_SCALE_MULT
		tree_exiting.connect(func() -> void: UiScale.physical_scale_multiplier = 1.0)
	if _files_panel and _card_session:
		_files_panel.card_selected.connect(_card_session.select_card)
		_files_panel.selection_cleared.connect(_card_session.clear)
		_files_panel.resource_deleted.connect(_card_session.handle_resource_deleted)
		_card_session.bind_files_panel(_files_panel)
