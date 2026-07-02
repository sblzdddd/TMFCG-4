@tool
extends ConfirmationDialog
class_name CreateCharacterDialog


signal character_created(character: DialogicCharacter, path: String)

@export var _name_edit: LineEdit
@export var _from_edit: LineEdit
@export var _description_edit: TextEdit
@export var _portrait_label: Label
@export var _upload_button: Button
@export var _choose_button: Button
@export var _builtin_checkbox: CheckBox

var _portrait_path: String = ""


func _ready() -> void:
	visible = false
	confirmed.connect(_on_confirmed)
	canceled.connect(_reset_form)
	close_requested.connect(_reset_form)
	_upload_button.pressed.connect(_on_upload_pressed)
	_choose_button.pressed.connect(_on_choose_pressed)


func popup_dialog() -> void:
	_reset_form()
	popup_centered()


func _reset_form() -> void:
	_name_edit.text = ""
	_from_edit.text = ""
	_description_edit.text = ""
	_portrait_path = ""
	_portrait_label.text = "(无)"
	if _builtin_checkbox:
		_builtin_checkbox.button_pressed = false


func _on_upload_pressed() -> void:
	ResourceFsUtils.pick_image_file(
		self,
		"上传立绘",
		_on_image_selected,
		FileDialog.ACCESS_FILESYSTEM
	)


func _on_choose_pressed() -> void:
	var builtin := _builtin_checkbox.button_pressed if _builtin_checkbox else false
	ResourceFsUtils.pick_image_file(
		self,
		"选择立绘",
		_on_image_selected,
		FileDialog.ACCESS_FILESYSTEM if not builtin else FileDialog.ACCESS_RESOURCES,
		ResourceFsUtils.get_textures_dir(builtin)
	)


func _on_image_selected(path: String) -> void:
	_portrait_path = path
	_portrait_label.text = path.get_file()


func _on_confirmed() -> void:
	var display_name := _name_edit.text.strip_edges()
	if display_name.is_empty():
		push_warning("Character name is required.")
		call_deferred("popup_centered")
		return

	var builtin := _builtin_checkbox.button_pressed if _builtin_checkbox else false
	if builtin and not ResourceFsUtils.can_write_presets():
		push_warning("Builtin characters can only be created from the Godot editor.")
		call_deferred("popup_centered")
		return

	var character := DialogicCharacter.new()
	character.display_name = display_name
	character.description = _build_description()

	var filename := ResourceFsUtils.sanitize_filename(display_name)
	var character_path := ResourceFsUtils.make_unique_path(
		ResourceFsUtils.get_characters_dir(builtin),
		filename,
		"dch"
	)

	if not _portrait_path.is_empty():
		var image_path := _portrait_path
		if _portrait_path.begins_with("res://") or _portrait_path.begins_with("user://"):
			if not builtin and _portrait_path.begins_with("res://"):
				image_path = ResourceFsUtils.import_image_file(
					_portrait_path,
					ResourceFsUtils.get_textures_dir(false),
					filename
				)
		else:
			image_path = ResourceFsUtils.import_image_file(
				_portrait_path,
				ResourceFsUtils.get_textures_dir(builtin),
				filename
			)

		if not image_path.is_empty():
			character.add_portrait("default", image_path)
			character.default_portrait = "default"

	var err := ResourceFsUtils.save_dialogic_character(character, character_path, builtin)
	if err != OK:
		push_error("Failed to save character: %s" % error_string(err))
		return

	character_created.emit(character, character_path)
	_reset_form()


func _build_description() -> String:
	var parts: PackedStringArray = []
	var origin := _from_edit.text.strip_edges()
	if not origin.is_empty():
		parts.append("origin=%s" % origin)
	var description := _description_edit.text.strip_edges()
	if not description.is_empty():
		parts.append("description=%s" % description)
	return "\n".join(parts)
