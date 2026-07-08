extends SceneTree

func _initialize() -> void:
	SkillNodeRegistry.initialize()
	var definition := SkillNodeRegistry.get_definition("array.join")
	if definition == null:
		push_error("Missing array.join definition")
		quit(1)
		return
	var node_script := definition.get_node_script()
	if node_script == null:
		push_error("Missing node script for %s" % definition.node_id)
		quit(1)
		return
	var node: BaseSkillNode = node_script.new()
	node.definition = definition
	node.refresh_view()
	if node.input_specs.is_empty():
		push_error("Join node specs were not initialized")
		quit(1)
		return
	print("Skill registry validation passed")
	quit()
