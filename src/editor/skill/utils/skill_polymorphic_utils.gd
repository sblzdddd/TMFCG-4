class_name SkillPolymorphicUtils
extends RefCounted

const PortType := SkillNodeSlotConstants.PortType


static func collect_groups(
	input_specs: Array[SkillInputSpec],
	output_specs: Array[SkillSlotSpec]
) -> Array[StringName]:
	var groups: Array[StringName] = []
	for spec in input_specs:
		if spec != null and spec.is_polymorphic() and not groups.has(spec.polymorphic_group):
			groups.append(spec.polymorphic_group)
	for spec in output_specs:
		if spec != null and spec.is_polymorphic() and not groups.has(spec.polymorphic_group):
			groups.append(spec.polymorphic_group)
	return groups


static func refresh_polymorphic_types(node: BaseSkillNode, graph: GraphEdit) -> void:
	if node.instance_state == null:
		return
	var groups := collect_groups(node.input_specs, node.output_specs)
	var next_types: Dictionary = {}
	for group in groups:
		var inferred := _infer_group_type(node, graph, group)
		if not SkillNodeSlotConstants.is_any_type(inferred):
			next_types[group] = inferred
	node.instance_state.polymorphic_types = next_types


static func refresh_all_polymorphic_types(graph: GraphEdit) -> void:
	var nodes: Array[BaseSkillNode] = []
	for child in graph.get_children():
		if child is BaseSkillNode:
			nodes.append(child)
	if nodes.is_empty():
		return
	var max_passes := nodes.size() + 1
	var changed := true
	while changed and max_passes > 0:
		changed = false
		max_passes -= 1
		for node in nodes:
			var before: Dictionary = node.instance_state.polymorphic_types.duplicate(true)
			refresh_polymorphic_types(node, graph)
			if before != node.instance_state.polymorphic_types:
				changed = true


static func effective_type(spec: SkillSlotSpec, resolved_types: Dictionary) -> int:
	if spec == null:
		return PortType.UNDEFINED
	if spec.is_polymorphic():
		var group: StringName = spec.polymorphic_group
		if resolved_types.has(group):
			return int(resolved_types[group])
		return PortType.ANY_ARRAY
	return spec.type


static func _infer_group_type(node: BaseSkillNode, graph: GraphEdit, group: StringName) -> int:
	var node_path := graph.get_path_to(node)
	for conn in graph.get_connection_list():
		if NodePath(conn["to_node"]) == node_path:
			var to_port: int = conn["to_port"]
			var spec := node._get_input_spec(to_port)
			if spec != null and spec.is_polymorphic() and spec.polymorphic_group == group:
				var from := graph.get_node_or_null(NodePath(conn["from_node"]))
				if from is BaseSkillNode:
					var connected_type := (from as BaseSkillNode).output_type(conn["from_port"])
					return _normalize_polymorphic_type(connected_type)
		if NodePath(conn["from_node"]) == node_path:
			var from_port: int = conn["from_port"]
			var spec := node._get_output_spec(from_port)
			if spec != null and spec.is_polymorphic() and spec.polymorphic_group == group:
				var to := graph.get_node_or_null(NodePath(conn["to_node"]))
				if to is BaseSkillNode:
					var connected_type := (to as BaseSkillNode).input_type(conn["to_port"])
					return _normalize_polymorphic_type(connected_type)
	return PortType.ANY_ARRAY


static func _normalize_polymorphic_type(type: int) -> int:
	if SkillNodeSlotConstants.is_any_type(type):
		return type
	if SkillNodeSlotConstants.is_array_type(type):
		return type
	return SkillNodeSlotConstants.array_type(type)
