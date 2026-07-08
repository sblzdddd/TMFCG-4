@tool
extends Tree
class_name SkillNodePalette

@export var skill_graph: SkillGraph

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	SkillNodeRegistry.initialize()
	SkillNodeRegistry.build_tree(self)
	if not item_activated.is_connected(_on_item_activated):
		item_activated.connect(_on_item_activated)


func _on_item_activated() -> void:
	if skill_graph == null or read_only():
		return
	var item := get_selected()
	if item == null:
		return
	var node_id: Variant = item.get_metadata(0)
	if typeof(node_id) != TYPE_STRING:
		return
	var definition := SkillNodeRegistry.get_definition(node_id)
	if definition == null:
		return
	skill_graph.spawn_node(definition, skill_graph.get_spawn_position())


func read_only() -> bool:
	return skill_graph != null and skill_graph.read_only
