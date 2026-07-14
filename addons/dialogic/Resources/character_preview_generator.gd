@tool
extends EditorResourcePreviewGenerator


func _handles(type: String) -> bool:
	return type == "DialogicCharacter" or type == "Resource"


func _generate(resource: Resource, size: Vector2i, _metadata: Dictionary) -> Texture2D:
	if not resource is DialogicCharacter:
		return null
	return (resource as DialogicCharacter).load_portrait_texture()


func _generate_from_path(path: String, size: Vector2i, _metadata: Dictionary) -> Texture2D:
	if not path.get_extension().to_lower() == "dch":
		return null

	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not resource is DialogicCharacter:
		return null
	return (resource as DialogicCharacter).load_portrait_texture()


func _generate_small_preview_automatically() -> bool:
	return true
