class_name SkillGraphSerializer
extends RefCounted


static func serialize_graph(graph: SkillGraph) -> Dictionary:
	var nodes: Array = []
	var id_by_path: Dictionary = {}
	for child in graph.get_children():
		if child is BaseSkillNode:
			var node := child as BaseSkillNode
			SkillInstanceStateUtils.capture_inline_values(node)
			var node_id := _ensure_instance_state(node)
			id_by_path[graph.get_path_to(node)] = node_id
			nodes.append({
				"id": node_id,
				"type": node.get_definition_id(),
				"position": [node.position_offset.x, node.position_offset.y],
				"polymorphic_types": node.instance_state.polymorphic_types.duplicate(true),
				"inline_values": node.instance_state.inline_values.duplicate(true),
			})
	var connections: Array = []
	for conn in graph.get_connection_list():
		var from_path := NodePath(conn["from_node"])
		var to_path := NodePath(conn["to_node"])
		if not id_by_path.has(from_path) or not id_by_path.has(to_path):
			continue
		connections.append({
			"from": id_by_path[from_path],
			"from_port": conn["from_port"],
			"to": id_by_path[to_path],
			"to_port": conn["to_port"],
		})
	return {"version": 1, "nodes": nodes, "connections": connections}


static func deserialize_graph(graph: SkillGraph, data: Dictionary) -> void:
	graph.clear_connections()
	_clear_skill_nodes(graph)
	var nodes_data: Array = data.get("nodes", [])
	var node_by_id: Dictionary = {}
	for entry in nodes_data:
		var definition := SkillNodeRegistry.get_definition(entry.get("type", ""))
		if definition == null:
			continue
		var position := Vector2.ZERO
		var pos_data: Array = entry.get("position", [])
		if pos_data.size() >= 2:
			position = Vector2(float(pos_data[0]), float(pos_data[1]))
		var node := graph.spawn_node(definition, position, String(entry.get("id", "")))
		node.instance_state.polymorphic_types = entry.get("polymorphic_types", {}).duplicate(true)
		node.instance_state.inline_values = entry.get("inline_values", {}).duplicate(true)
		node.refresh_view()
		node_by_id[node.instance_state.graph_node_name] = node
	for conn in data.get("connections", []):
		var from_node: BaseSkillNode = node_by_id.get(conn.get("from", ""))
		var to_node: BaseSkillNode = node_by_id.get(conn.get("to", ""))
		if from_node == null or to_node == null:
			continue
		graph.connect_node(
			from_node.name,
			int(conn.get("from_port", 0)),
			to_node.name,
			int(conn.get("to_port", 0))
		)
	SkillPolymorphicUtils.refresh_all_polymorphic_types(graph)
	for node: BaseSkillNode in node_by_id.values():
		node.refresh_view()


static func _clear_skill_nodes(graph: SkillGraph) -> void:
	var to_remove: Array[BaseSkillNode] = []
	for child in graph.get_children():
		if child is BaseSkillNode:
			to_remove.append(child)
	for node in to_remove:
		node.free()


static func _ensure_instance_state(node: BaseSkillNode) -> String:
	if node.instance_state == null:
		node.instance_state = SkillNodeInstanceState.new()
	if node.instance_state.graph_node_name.is_empty():
		node.instance_state.graph_node_name = node.name
	node.instance_state.node_id = node.get_definition_id()
	node.instance_state.position = node.position_offset
	return node.instance_state.graph_node_name
