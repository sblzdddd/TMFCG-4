@tool
extends DialogicPortrait

@export_file var image := ""
@onready var _portrait: Sprite2D = $Portrait

const SHADER_OPACITY := &"opacity"
var _opacity_sync_scheduled := false


func _ready() -> void:
	_ensure_unique_material()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _opacity_sync_scheduled:
		return
	_opacity_sync_scheduled = true
	call_deferred("_deferred_sync_shader_opacity")


func _should_do_portrait_update(_character: DialogicCharacter, _portrait_name: String) -> bool:
	return true


func _update_portrait(passed_character: DialogicCharacter, passed_portrait: String) -> void:
	apply_character_and_portrait(passed_character, passed_portrait)
	_ensure_unique_material()
	apply_texture(_get_portrait_sprite(), image)
	call_deferred("_deferred_sync_shader_opacity")


func _deferred_sync_shader_opacity() -> void:
	_opacity_sync_scheduled = false
	_sync_shader_opacity()


func _sync_shader_opacity() -> void:
	var material := _get_shader_material()
	if material == null:
		return

	var opacity := _get_effective_opacity()
	material.set_shader_parameter(SHADER_OPACITY, opacity)

	# Shader replaces COLOR entirely, so node modulate must be driven via the uniform.
	# Reset after reading so tweens can keep writing modulate without double-applying.
	_clear_canvas_item_modulate(self)
	var parent := get_parent()
	if parent is CanvasItem:
		_clear_canvas_item_modulate(parent)


func _get_effective_opacity() -> float:
	var opacity := 1.0
	if has_method(&"get") and get("modulate") is Color:
		opacity *= (get("modulate") as Color).a
	var parent := get_parent()
	if parent is CanvasItem:
		opacity *= (parent as CanvasItem).modulate.a
	return opacity


func _clear_canvas_item_modulate(item: Node) -> void:
	if item == self:
		if get("modulate") is Color and get("modulate") != Color.WHITE:
			set("modulate", Color.WHITE)
		return
	if item is CanvasItem:
		var canvas_item := item as CanvasItem
		if canvas_item.modulate != Color.WHITE:
			canvas_item.modulate = Color.WHITE


func _ensure_unique_material() -> void:
	var sprite := _get_portrait_sprite()
	if sprite == null or sprite.material == null:
		return
	if sprite.has_meta(&"material_duplicated"):
		return
	sprite.material = sprite.material.duplicate()
	sprite.set_meta(&"material_duplicated", true)


func _get_portrait_sprite() -> Sprite2D:
	if is_instance_valid(_portrait):
		return _portrait
	return get_node_or_null("Portrait") as Sprite2D


func _get_shader_material() -> ShaderMaterial:
	var sprite := _get_portrait_sprite()
	if sprite == null:
		return null
	return sprite.material as ShaderMaterial
