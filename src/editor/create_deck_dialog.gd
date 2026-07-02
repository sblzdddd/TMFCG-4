@tool
extends ConfirmationDialog
class_name CreateDeckDialog


signal deck_created(deck: DeckData, path: String)

@export var _name_edit: LineEdit
@export var _author_edit: LineEdit
@export var _description_edit: TextEdit
@export var _thumbnail_label: Label
@export var _upload_button: Button
@export var _choose_button: Button
@export var _builtin_checkbox: CheckBox

var _thumbnail_path: String = ""


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
	_author_edit.text = ""
	_description_edit.text = ""
	_thumbnail_path = ""
	_thumbnail_label.text = "(无)"
	if _builtin_checkbox:
		_builtin_checkbox.button_pressed = false


func _on_upload_pressed() -> void:
	ResourceFsUtils.pick_image_file(
		self,
		"上传缩略图",
		_on_image_selected,
		FileDialog.ACCESS_FILESYSTEM
	)


func _on_choose_pressed() -> void:
	var builtin := _builtin_checkbox.button_pressed if _builtin_checkbox else false
	ResourceFsUtils.pick_image_file(
		self,
		"选择缩略图",
		_on_image_selected,
		FileDialog.ACCESS_FILESYSTEM if not builtin else FileDialog.ACCESS_RESOURCES,
		ResourceFsUtils.get_deck_textures_dir(builtin)
	)


func _on_image_selected(path: String) -> void:
	_thumbnail_path = path
	_thumbnail_label.text = path.get_file()


func _on_confirmed() -> void:
	var deck_name := _name_edit.text.strip_edges()
	if deck_name.is_empty():
		push_warning("Deck name is required.")
		call_deferred("popup_centered")
		return

	var builtin := _builtin_checkbox.button_pressed if _builtin_checkbox else false
	if builtin and not ResourceFsUtils.can_write_presets():
		push_warning("Builtin decks can only be created from the Godot editor.")
		call_deferred("popup_centered")
		return

	var filename := ResourceFsUtils.sanitize_filename(deck_name)
	var deck_path := ResourceFsUtils.make_unique_path(
		ResourceFsUtils.get_decks_dir(builtin),
		filename,
		"tres"
	)

	var deck := DeckData.new()
	deck.name = deck_name
	deck.author = _author_edit.text.strip_edges()
	deck.description = _description_edit.text.strip_edges()
	deck.id = "deck-%d" % Time.get_unix_time_from_system()
	deck.date_created = Time.get_unix_time_from_system()
	deck.date_modified = deck.date_created

	if not _thumbnail_path.is_empty():
		var image_path := _resolve_thumbnail_path(filename, builtin)
		if not image_path.is_empty():
			deck.thumbnail = ResourceFsUtils.load_texture(image_path)

	var err := ResourceFsUtils.save_resource(deck, deck_path)
	if err != OK:
		push_error("Failed to save deck: %s" % error_string(err))
		return

	deck_created.emit(deck, deck_path)
	_reset_form()


func _resolve_thumbnail_path(filename: String, builtin: bool) -> String:
	if _thumbnail_path.begins_with("res://") or _thumbnail_path.begins_with("user://"):
		if not builtin and _thumbnail_path.begins_with("res://"):
			return ResourceFsUtils.import_image_file(
				_thumbnail_path,
				ResourceFsUtils.get_deck_textures_dir(false),
				filename
			)
		return _thumbnail_path

	return ResourceFsUtils.import_image_file(
		_thumbnail_path,
		ResourceFsUtils.get_deck_textures_dir(builtin),
		filename
	)
