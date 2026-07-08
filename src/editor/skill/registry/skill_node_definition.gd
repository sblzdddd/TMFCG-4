@tool
class_name SkillNodeDefinition
extends Resource

@export var node_id: String = ""
@export var display_name: String = ""
@export var category: SkillNodeCategoryConstants.Category = SkillNodeCategoryConstants.Category.EVENT
@export_file("*.gd") var node_script_path: String = ""
@export var min_size: Vector2 = Vector2(200, 50)
@export var input_slot_specs: Array[SkillInputSpec] = []
@export var output_slot_specs: Array[SkillSlotSpec] = []


func get_node_script() -> Script:
	if node_script_path.is_empty():
		return null
	return load(node_script_path) as Script


func duplicate_specs() -> Dictionary:
	var inputs: Array[SkillInputSpec] = []
	for spec in input_slot_specs:
		inputs.append(spec.duplicate(true) as SkillInputSpec)
	var outputs: Array[SkillSlotSpec] = []
	for spec in output_slot_specs:
		outputs.append(spec.duplicate(true) as SkillSlotSpec)
	return {"input": inputs, "output": outputs}
