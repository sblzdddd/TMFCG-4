@tool
class_name UiCardItem
extends PanelContainer
## Single selectable UI list row: title + subtitle + optional trailing action.

signal selected(id: String)
signal activated(id: String)
signal action_pressed(id: String, action_id: String)

@export var entry: UiCardEntry:
	set(value):
		if entry != value:
			_disconnect_entry()
			entry = value
			_connect_entry()
		_apply_entry()

@onready var _title_label: Label = %Title
@onready var _subtitle_label: Label = %Subtitle
@onready var _icon: TextureRect = %Icon
@onready var _icon_container: PanelContainer = %IconContainer
@onready var _action_button: Button = %ActionButton
@onready var _select_button: Button = %SelectButton

var id: String = ""
var action_id: String = ""
var _panel_style: StyleBoxFlat
var _panel_content_margins: Vector4
var selected_state := false:
	set(value):
		selected_state = value
		_apply_selected_visual()


func _ready() -> void:
	clip_contents = true
	_configure_text_ellipsis(_resolve_title_label())
	_configure_text_ellipsis(_resolve_subtitle_label())
	if not Engine.is_editor_hint():
		var select_button := _resolve_select_button()
		var action_button := _resolve_action_button()
		if select_button:
			if not select_button.pressed.is_connected(_on_select_pressed):
				select_button.pressed.connect(_on_select_pressed)
			if not select_button.gui_input.is_connected(_on_select_gui_input):
				select_button.gui_input.connect(_on_select_gui_input)
		if action_button:
			if not action_button.pressed.is_connected(_on_action_pressed):
				action_button.pressed.connect(_on_action_pressed)
			# Keep action clickable above the select overlay.
			action_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_entry()
	_apply_entry()
	_apply_selected_visual()


func _configure_text_ellipsis(label: Label) -> void:
	if label == null:
		return
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func configure(p_entry: UiCardEntry) -> void:
	entry = p_entry


func _connect_entry() -> void:
	if entry == null:
		return
	if not entry.changed.is_connected(_on_entry_changed):
		entry.changed.connect(_on_entry_changed)


func _disconnect_entry() -> void:
	if entry == null:
		return
	if entry.changed.is_connected(_on_entry_changed):
		entry.changed.disconnect(_on_entry_changed)


func _on_entry_changed() -> void:
	_apply_entry()


func _apply_entry() -> void:
	if entry == null or not is_node_ready():
		return
	id = entry.id
	action_id = entry.action_id
	var title_label := _resolve_title_label()
	var subtitle_label := _resolve_subtitle_label()
	var icon := _resolve_icon()
	var icon_container := _resolve_icon_container()
	var action_button := _resolve_action_button()
	if (
		title_label == null
		or subtitle_label == null
		or icon == null
		or icon_container == null
		or action_button == null
	):
		return
	title_label.text = entry.title
	subtitle_label.text = entry.subtitle
	subtitle_label.visible = not entry.subtitle.is_empty()
	icon.texture = entry.icon
	icon_container.visible = entry.icon != null
	action_button.text = entry.action_text
	action_button.visible = not entry.action_text.is_empty()
	_apply_background()


func _apply_background() -> void:
	if not is_instance_valid(_panel_style):
		var style := get_theme_stylebox(&"panel")
		if not style is StyleBoxFlat:
			return
		_panel_style = style.duplicate()
		_panel_content_margins = Vector4(
			_panel_style.content_margin_left,
			_panel_style.content_margin_top,
			_panel_style.content_margin_right,
			_panel_style.content_margin_bottom,
		)
		add_theme_stylebox_override(&"panel", _panel_style)

	_panel_style.draw_center = entry.draw_background
	_panel_style.content_margin_left = _panel_content_margins.x if entry.draw_background else 0.0
	_panel_style.content_margin_top = _panel_content_margins.y if entry.draw_background else 0.0
	_panel_style.content_margin_right = _panel_content_margins.z if entry.draw_background else 0.0
	_panel_style.content_margin_bottom = _panel_content_margins.w if entry.draw_background else 0.0


func _on_select_pressed() -> void:
	selected.emit(id)


func _on_select_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click:
		activated.emit(id)
		var select_button := _resolve_select_button()
		if select_button:
			select_button.accept_event()


func _on_action_pressed() -> void:
	action_pressed.emit(id, action_id)


func _apply_selected_visual() -> void:
	modulate = Color(1.15, 1.15, 1.2, 1.0) if selected_state else Color.WHITE


func _resolve_title_label() -> Label:
	if is_instance_valid(_title_label):
		return _title_label
	return get_node_or_null("%Title") as Label


func _resolve_subtitle_label() -> Label:
	if is_instance_valid(_subtitle_label):
		return _subtitle_label
	return get_node_or_null("%Subtitle") as Label


func _resolve_icon() -> TextureRect:
	if is_instance_valid(_icon):
		return _icon
	return get_node_or_null("%Icon") as TextureRect


func _resolve_icon_container() -> PanelContainer:
	if is_instance_valid(_icon_container):
		return _icon_container
	return get_node_or_null("%IconContainer") as PanelContainer


func _resolve_action_button() -> Button:
	if is_instance_valid(_action_button):
		return _action_button
	return get_node_or_null("%ActionButton") as Button


func _resolve_select_button() -> Button:
	if is_instance_valid(_select_button):
		return _select_button
	return get_node_or_null("%SelectButton") as Button
