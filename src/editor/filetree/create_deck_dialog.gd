extends ConfirmationDialog
class_name CreateDeckDialog

signal deck_created(deck: DeckData, path: String)

@export var _name_edit: LineEdit
@export var _author_edit: LineEdit
@export var _description_edit: TextEdit
@export var _builtin_checkbox: CheckBox


func _ready() -> void:
	visible = false
	confirmed.connect(_on_confirmed)
	canceled.connect(_reset_form)
	close_requested.connect(_reset_form)


func popup_dialog() -> void:
	_reset_form()
	popup_centered()


func _reset_form() -> void:
	_name_edit.text = ""
	_author_edit.text = ""
	_description_edit.text = ""
	if _builtin_checkbox:
		_builtin_checkbox.button_pressed = false


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
		builtin,
	)
	if result.is_empty():
		call_deferred("popup_centered")
		return

	deck_created.emit(result["deck"], result["path"])
	_reset_form()
