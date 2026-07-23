extends GraphEdit
class_name SkillGraph

signal graph_changed()

@export var read_only := false:
	set(value):
		read_only = value
		for child in get_children():
			if child is GraphNode:
				child.draggable = not read_only
				child.selectable = not read_only

var _spawn_counter := 0
var _keyboard := SkillGraphKeyboard.new()
var _spawn_menu := SkillNodeSpawnMenu.new()

func _ready() -> void:
	SkillNodeRegistry.initialize()
	_register_connection_types()
	type_names = SkillNodeSlotConstants.build_type_names()
	if not connection_request.is_connected(_on_connection_request):
		connection_request.connect(_on_connection_request)
	if not disconnection_request.is_connected(_on_disconnection_request):
		disconnection_request.connect(_on_disconnection_request)
	if not delete_nodes_request.is_connected(_on_delete_nodes_request):
		delete_nodes_request.connect(_on_delete_nodes_request)
	call_deferred("_refresh_all_skill_nodes")
	_spawn_menu.setup(self)
	add_child(_spawn_menu)
	_keyboard.bind(self)


func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if not _is_click_on_graph_node(mouse_event.position):
				open_spawn_menu(get_screen_position() + mouse_event.position, _local_to_graph_position(mouse_event.position))
				accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if _keyboard.handle_unhandled_key_input(event):
		get_viewport().set_input_as_handled()


func record_undo() -> void:
	_keyboard.record_undo()
	_notify_graph_changed()


func notify_content_changed() -> void:
	_notify_graph_changed()


func _notify_graph_changed() -> void:
	if not _loading:
		graph_changed.emit()


func set_loading(value: bool) -> void:
	_loading = value


var _loading := false


func _refresh_all_skill_nodes() -> void:
	SkillPolymorphicUtils.refresh_all_polymorphic_types(self)
	for child in get_children():
		if child is BaseSkillNode:
			(child as BaseSkillNode).refresh_view()


func spawn_node(
	definition: SkillNodeDefinition,
	node_position: Vector2,
	graph_node_name: String = ""
) -> BaseSkillNode:
	if definition == null:
		push_error("Cannot spawn skill node without a definition")
		return null
	var node_script := definition.get_node_script()
	if node_script == null:
		push_error("Missing node script for %s" % definition.node_id)
		return null
	# Avoid typed assignment on .new() — fails when scripts briefly fail to resolve BaseSkillNode.
	var instance: Variant = node_script.new()
	if not (instance is BaseSkillNode):
		push_error(
			"Node script for %s did not instantiate as BaseSkillNode (got %s)"
			% [definition.node_id, instance]
		)
		if instance is Node:
			(instance as Node).free()
		return null
	var node := instance as BaseSkillNode
	node.definition = definition
	node.name = graph_node_name if not graph_node_name.is_empty() else _unique_node_name(definition.node_id)
	node.position_offset = node_position
	add_child(node)
	node.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	node.refresh_view()
	_notify_graph_changed()
	return node


func get_spawn_position() -> Vector2:
	return scroll_offset + size * 0.5


func open_spawn_menu(screen_position: Vector2, spawn_position: Vector2) -> void:
	if read_only:
		return
	_spawn_menu.open_at(screen_position, spawn_position)


func get_mouse_screen_position() -> Vector2:
	return get_screen_position() + get_local_mouse_position()


func get_mouse_graph_position() -> Vector2:
	return _local_to_graph_position(get_local_mouse_position())


func _local_to_graph_position(local_position: Vector2) -> Vector2:
	return (local_position + scroll_offset) / zoom


func _is_click_on_graph_node(local_position: Vector2) -> bool:
	var graph_position := _local_to_graph_position(local_position)
	for child in get_children():
		if child is GraphNode and child.visible:
			var node_rect := Rect2(child.position_offset, child.size * child.scale)
			if node_rect.has_point(graph_position):
				return true
	return false


func _register_connection_types() -> void:
	var any_type := SkillNodeSlotConstants.graph_port_type(SkillNodeSlotConstants.PortType.ANY)
	for key: int in SkillNodeSlotConstants.TYPE_INFO.keys():
		if key == SkillNodeSlotConstants.PortType.UNDEFINED:
			continue
		add_valid_connection_type(key, key)
		add_valid_right_disconnect_type(key)
		add_valid_connection_type(key, any_type)
		add_valid_connection_type(any_type, key)
	add_valid_connection_type(any_type, any_type)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if read_only:
		return
	# GraphEdit may commit the drag before emitting connection_request.
	if is_node_connected(from_node, from_port, to_node, to_port):
		disconnect_node(from_node, from_port, to_node, to_port)
	record_undo()
	var from := get_node_or_null(NodePath(from_node))
	var to := get_node_or_null(NodePath(to_node))
	if from is BaseSkillNode and to is BaseSkillNode:
		var to_skill := to as BaseSkillNode
		if to_skill.can_connect_to(from as BaseSkillNode, from_port, to_port):
			to_skill.clear_input_connections(self, to_port)
			connect_node(from_node, from_port, to_node, to_port)
			_refresh_all_skill_nodes()
		_notify_graph_changed()
		return
	connect_node(from_node, from_port, to_node, to_port)
	_notify_graph_changed()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if read_only:
		return
	record_undo()
	var from := get_node_or_null(NodePath(from_node))
	var to := get_node_or_null(NodePath(to_node))
	disconnect_node(from_node, from_port, to_node, to_port)
	if from is BaseSkillNode or to is BaseSkillNode:
		_refresh_all_skill_nodes()
	_notify_graph_changed()


	_notify_graph_changed()


func _on_delete_nodes_request(_node_names: Array[StringName]) -> void:
	call_deferred("_notify_graph_changed")


func _unique_node_name(node_id: String) -> String:
	_spawn_counter += 1
	var safe_id := node_id.replace(".", "_")
	return "%s_%d" % [safe_id, _spawn_counter]
