extends Button

@export var RootPanel: PanelContainer
@export var Avatar: TextureRect
@export var EditIcon: TextureRect

var _tween: Tween = null

func _ready() -> void:
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)


func _on_hover() -> void:
	if _tween != null: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(RootPanel, "offset_transform_scale", Vector2(0.9, 0.9), 0.3)
	_tween.tween_property(Avatar, "modulate", Color(0.7, 0.7, 0.7, 1.0), 0.2)
	_tween.tween_property(EditIcon, "offset_transform_scale", Vector2(0.5, 0.5), 0.3)

func _on_unhover() -> void:
	if _tween != null: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(RootPanel, "offset_transform_scale", Vector2(1, 1), 0.3)
	_tween.tween_property(Avatar, "modulate", Color.WHITE, 0.2)
	_tween.tween_property(EditIcon, "offset_transform_scale", Vector2.ZERO, 0.3)
