class_name SkillGraphKeyboard
extends RefCounted

const DUPLICATE_OFFSET := Vector2(40, 40)
const MAX_UNDO_STEPS := 50

var _graph: SkillGraph
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _undo_locked := false


func bind(graph: SkillGraph) -> void:
	_graph = graph
	if not graph.delete_nodes_request.is_connected(_on_delete_nodes_request):
		graph.delete_nodes_request.connect(_on_delete_nodes_request)
	if not graph.duplicate_nodes_request.is_connected(_on_duplicate_nodes_request):
		graph.duplicate_nodes_request.connect(_on_duplicate_nodes_request)
	if not graph.begin_node_move.is_connected(_on_begin_node_move):
		graph.begin_node_move.connect(_on_begin_node_move)


func record_undo() -> void:
	_record_undo()


func _on_begin_node_move() -> void:
	_record_undo()


func handle_unhandled_key_input(event: InputEvent) -> bool:
	if _graph == null or _graph.read_only:
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if _is_text_focused():
		return false
	if not (event.ctrl_pressed or event.meta_pressed):
		return false
	match event.keycode:
		KEY_Z:
			if event.shift_pressed:
				return redo()
			return undo()
		KEY_Y:
			return redo()
	return false


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	if _graph == null or _graph.read_only or node_names.is_empty():
		return
	_record_undo()
	for node_name in node_names:
		_disconnect_node(node_name)
		var node := _graph.get_node_or_null(NodePath(node_name))
		if node is BaseSkillNode:
			node.queue_free()
	_graph.call_deferred("_refresh_all_skill_nodes")


func _on_duplicate_nodes_request() -> void:
	if _graph == null or _graph.read_only:
		return
	var selected := _get_selected_skill_nodes()
	if selected.is_empty():
		return
	_record_undo()
	var name_map: Dictionary = {}
	for node in selected:
		var snapshot: Dictionary = node.capture_instance_state()
		var duplicate := _graph.spawn_node(
			node.definition,
			node.position_offset + DUPLICATE_OFFSET
		)
		duplicate.apply_instance_state_snapshot(snapshot)
		name_map[node.name] = duplicate.name
		node.selected = false
		duplicate.selected = true
	_copy_internal_connections(name_map)
	SkillPolymorphicUtils.refresh_all_polymorphic_types(_graph)
	for duplicate_name: String in name_map.values():
		var duplicate := _graph.get_node_or_null(NodePath(duplicate_name))
		if duplicate is BaseSkillNode:
			(duplicate as BaseSkillNode).refresh_view()


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_push_current_to_redo()
	var state: Dictionary = _undo_stack.pop_back()
	_undo_locked = true
	SkillGraphSerializer.deserialize_graph(_graph, state)
	_undo_locked = false
	if _graph.has_method("notify_content_changed"):
		_graph.notify_content_changed()
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	_push_current_to_undo()
	var state: Dictionary = _redo_stack.pop_back()
	_undo_locked = true
	SkillGraphSerializer.deserialize_graph(_graph, state)
	_undo_locked = false
	if _graph.has_method("notify_content_changed"):
		_graph.notify_content_changed()
	return true


func _record_undo() -> void:
	if _undo_locked or _graph == null or _graph.read_only:
		return
	_capture_graph_state()
	_undo_stack.append(SkillGraphSerializer.serialize_graph(_graph))
	_redo_stack.clear()
	while _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()


func _push_current_to_redo() -> void:
	_capture_graph_state()
	_redo_stack.append(SkillGraphSerializer.serialize_graph(_graph))


func _push_current_to_undo() -> void:
	_capture_graph_state()
	_undo_stack.append(SkillGraphSerializer.serialize_graph(_graph))


func _capture_graph_state() -> void:
	for child in _graph.get_children():
		if child is BaseSkillNode:
			SkillInstanceStateUtils.capture_inline_values(child)


func _get_selected_skill_nodes() -> Array[BaseSkillNode]:
	var nodes: Array[BaseSkillNode] = []
	for child in _graph.get_children():
		if child is BaseSkillNode and child.selected:
			nodes.append(child)
	return nodes


func _copy_internal_connections(name_map: Dictionary) -> void:
	for conn in _graph.get_connection_list():
		var from_name: String = conn["from_node"]
		var to_name: String = conn["to_node"]
		if not name_map.has(from_name) or not name_map.has(to_name):
			continue
		_graph.connect_node(
			name_map[from_name],
			conn["from_port"],
			name_map[to_name],
			conn["to_port"]
		)


func _disconnect_node(node_name: StringName) -> void:
	var pending: Array = []
	for conn in _graph.get_connection_list():
		if conn["from_node"] == node_name or conn["to_node"] == node_name:
			pending.append(conn)
	for conn in pending:
		_graph.disconnect_node(
			conn["from_node"],
			conn["from_port"],
			conn["to_node"],
			conn["to_port"]
		)


func _is_text_focused() -> bool:
	var focus := _graph.get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or focus is CodeEdit
