@tool
class_name SkillNodeDefinition
extends Resource

const DEFINITIONS_ROOT := "res://src/editor/skill/definitions/"
const NODES_ROOT := "res://src/editor/skill/nodes/"

@export var node_id: String = ""
@export var display_name: String = ""
@export var category: SkillNodeCategoryConstants.Category = SkillNodeCategoryConstants.Category.EVENT
@export var min_size: Vector2 = Vector2(200, 50)
@export var input_slot_specs: Array[SkillInputSpec] = []
@export var output_slot_specs: Array[SkillSlotSpec] = []

@export_tool_button("Create Node Script")
var create_node_script_button:
	get: return _create_node_script


static func resolve_node_script_path(definition_path: String) -> String:
	if definition_path.is_empty() or not definition_path.begins_with(DEFINITIONS_ROOT):
		return ""
	var relative := definition_path.trim_prefix(DEFINITIONS_ROOT)
	if relative.get_extension() != "tres":
		return ""
	return NODES_ROOT.path_join(relative.get_basename() + ".gd")


static func resolve_definition_path(script_path: String) -> String:
	if script_path.is_empty() or not script_path.begins_with(NODES_ROOT):
		return ""
	var relative := script_path.trim_prefix(NODES_ROOT)
	if relative.get_extension() != "gd":
		return ""
	return DEFINITIONS_ROOT.path_join(relative.get_basename() + ".tres")


func get_resolved_node_script_path() -> String:
	return resolve_node_script_path(resource_path)


func has_node_script() -> bool:
	var path := get_resolved_node_script_path()
	return not path.is_empty() and ResourceLoader.exists(path)


func get_node_script() -> Script:
	var path := get_resolved_node_script_path()
	if path.is_empty():
		push_warning(
			"SkillNodeDefinition '%s' has no resolvable node script path (resource_path=%s)."
			% [node_id, resource_path]
		)
		return null
	if not ResourceLoader.exists(path):
		push_warning(
			"SkillNodeDefinition '%s' is missing node script at %s."
			% [node_id if not node_id.is_empty() else resource_path, path]
		)
		return null
	return load(path) as Script


func duplicate_specs() -> Dictionary:
	var inputs: Array[SkillInputSpec] = []
	for spec in input_slot_specs:
		inputs.append(spec.duplicate(true) as SkillInputSpec)
	var outputs: Array[SkillSlotSpec] = []
	for spec in output_slot_specs:
		outputs.append(spec.duplicate(true) as SkillSlotSpec)
	return {"input": inputs, "output": outputs}


func _create_node_script() -> void:
	if not Engine.is_editor_hint():
		return
	var path := get_resolved_node_script_path()
	if path.is_empty():
		push_warning(
			"Cannot create node script for '%s': save the definition under %s first."
			% [node_id if not node_id.is_empty() else "<unsaved>", DEFINITIONS_ROOT]
		)
		return
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		push_warning("Node script already exists at %s." % path)
		_edit_script(path)
		return

	var dir_path := path.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	if err != OK:
		push_error("Failed to create directory %s: %s" % [dir_path, error_string(err)])
		return

	var class_name_str := _class_name_from_script_path(path)
	var source := "@tool\nclass_name %s extends BaseSkillNode\n" % class_name_str
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write node script at %s." % path)
		return
	file.store_string(source)
	file.close()

	if Engine.has_singleton("EditorInterface"):
		var editor_interface := Engine.get_singleton("EditorInterface")
		editor_interface.get_resource_filesystem().scan()
	print("Created skill node script: %s" % path)
	_edit_script(path)


func _edit_script(path: String) -> void:
	if not Engine.has_singleton("EditorInterface"):
		return
	var editor_interface := Engine.get_singleton("EditorInterface")
	var script := load(path) as Script
	if script != null:
		editor_interface.edit_script(script)


static func _class_name_from_script_path(path: String) -> String:
	var base := path.get_file().get_basename()
	var parts := base.split("_")
	var class_name_str := ""
	for part in parts:
		if part.is_empty():
			continue
		class_name_str += part.substr(0, 1).to_upper() + part.substr(1)
	if class_name_str.is_empty():
		return "SkillNode"
	return class_name_str
