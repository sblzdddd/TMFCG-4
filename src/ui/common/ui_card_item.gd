class_name UiCardItem
extends PanelContainer
## Single selectable UI list row: title + subtitle + optional trailing action.

signal selected(id: String)
signal activated(id: String)
signal action_pressed(id: String, action_id: String)

@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _icon: TextureRect = %Icon
@onready var _icon_container: PanelContainer = %IconContainer
@onready var _action_button: Button = %ActionButton
@onready var _select_button: Button = %SelectButton

var id: String = ""
var action_id: String = ""
var selected_state := false:
	set(value):
		selected_state = value
		_apply_selected_visual()


func _ready() -> void:
	_select_button.pressed.connect(_on_select_pressed)
	_select_button.gui_input.connect(_on_select_gui_input)
	_action_button.pressed.connect(_on_action_pressed)
	# Keep action clickable above the select overlay.
	_action_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_selected_visual()


func configure(entry: UiCardEntry) -> void:
	if entry == null:
		return
	id = entry.id
	action_id = entry.action_id
	if _title_label:
		_title_label.text = entry.title
	if _subtitle_label:
		_subtitle_label.text = entry.subtitle
		_subtitle_label.visible = not entry.subtitle.is_empty()
	if _icon:
		_icon.texture = entry.icon
		_icon_container.visible = entry.icon != null
	if _action_button:
		_action_button.text = entry.action_text
		_action_button.visible = not entry.action_text.is_empty()


func _on_select_pressed() -> void:
	selected.emit(id)


func _on_select_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click:
		activated.emit(id)
		_select_button.accept_event()


func _on_action_pressed() -> void:
	action_pressed.emit(id, action_id)


func _apply_selected_visual() -> void:
	modulate = Color(1.15, 1.15, 1.2, 1.0) if selected_state else Color.WHITE
