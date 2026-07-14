extends HBoxContainer
class_name UserProfileEditor

@export var _avatar_button: Button
@export var _random_name_button: Button
@export var _avatar_rect: TextureRect
@export var _name_edit: LabelLineEdit
@export var _avatar_picker: AvatarPickerDialog

var _loading := false


func _ready() -> void:
	if _avatar_button:
		_avatar_button.pressed.connect(_on_avatar_button_pressed)
	if _random_name_button:
		_random_name_button.pressed.connect(_on_random_name_pressed)
	if _avatar_picker:
		_avatar_picker.avatar_selected.connect(_on_avatar_selected)
	if _name_edit:
		_name_edit.text_submitted.connect(_on_name_submitted)
		_name_edit.focus_exited.connect(_on_name_focus_exited)

	PlayerDataStore.data_changed.connect(_on_store_data_changed)
	_apply_data(PlayerDataStore.data)


func _on_random_name_pressed() -> void:
	PlayerDataStore.set_display_name(PlayerDataStore.random_display_name())


func _on_avatar_button_pressed() -> void:
	if _avatar_picker:
		_avatar_picker.popup_picker()


func _on_avatar_selected(avatar_id: String) -> void:
	PlayerDataStore.set_avatar_id(avatar_id)


func _on_name_submitted(new_text: String) -> void:
	_commit_name(new_text)


func _on_name_focus_exited() -> void:
	if _name_edit:
		_commit_name(_name_edit.text)


func _commit_name(new_text: String) -> void:
	if _loading:
		return
	PlayerDataStore.set_display_name(new_text)


func _on_store_data_changed(data: PlayerData) -> void:
	_apply_data(data)


func _apply_data(data: PlayerData) -> void:
	if data == null:
		return
	_loading = true
	if _avatar_rect:
		_avatar_rect.texture = data.avatar
	if _name_edit and not _name_edit.has_focus():
		_name_edit.set_text_content(data.name)
	_loading = false
