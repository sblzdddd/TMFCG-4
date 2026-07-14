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
@export var _image_picker: ImagePickerDialog

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
	_image_picker.pick(
		ResConst.ImageKind.DECK_THUMBNAIL,
		ResConst.ImagePickMode.UPLOAD,
		false,
		_on_image_selected
	)


func _on_choose_pressed() -> void:
	var builtin := _builtin_checkbox.button_pressed if _builtin_checkbox else false
	_image_picker.pick(
		ResConst.ImageKind.DECK_THUMBNAIL,
		ResConst.ImagePickMode.CHOOSE,
		builtin,
		_on_image_selected
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
	var result := DeckDataStore.create_deck(
		deck_name,
		_author_edit.text,
		_description_edit.text,
		_thumbnail_path,
		builtin,
	)
	if result.is_empty():
		call_deferred("popup_centered")
		return

	deck_created.emit(result["deck"], result["path"])
	_reset_form()
