extends Button

const TITLE_SCENE := "res://definitions/levels/title.tscn"

@export var _exit_confirm_dialog: ConfirmationDialog


func _ready() -> void:
	pressed.connect(_on_exit_pressed)
	if _exit_confirm_dialog:
		_exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)


func _on_exit_pressed() -> void:
	if _exit_confirm_dialog:
		_exit_confirm_dialog.popup_centered()
	else:
		_on_exit_confirmed()


func _on_exit_confirmed() -> void:
	LevelLoader.load_level(TITLE_SCENE)
