@tool
extends GraphEdit
class_name SkillGraph

@export var read_only := false:
	set(value):
		read_only = value
		for child in get_children():
			if child is GraphNode:
				child.draggable = not read_only
				child.selectable = not read_only

@export_tool_button("Print Serialized Graph")
var _print_serialized_graph_button:
	get: return _print_serialized_graph

var _spawn_counter := 0
var _keyboard := SkillGraphKeyboard.new()

func _ready() -> void:
	SkillNodeRegistry.initialize()
	_register_connection_types()
	type_names = SkillNodeSlotConstants.build_type_names()
	if not connection_request.is_connected(_on_connection_request):
		connection_request.connect(_on_connection_request)
	if not disconnection_request.is_connected(_on_disconnection_request):
		disconnection_request.connect(_on_disconnection_request)
	call_deferred("_refresh_all_skill_nodes")
	_keyboard.bind(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if _keyboard.handle_unhandled_key_input(event):
		get_viewport().set_input_as_handled()


func record_undo() -> void:
	_keyboard.record_undo()


func _refresh_all_skill_nodes() -> void:
	SkillPolymorphicUtils.refresh_all_polymorphic_types(self)
	for child in get_children():
		if child is BaseSkillNode:
			(child as BaseSkillNode).refresh_view()


func spawn_node(
	definition: SkillNodeDefinition,
	position: Vector2,
	graph_node_name: String = ""
) -> BaseSkillNode:
	var node_script := definition.get_node_script()
	if node_script == null:
		push_error("Missing node script for %s" % definition.node_id)
		return null
	var node: BaseSkillNode = node_script.new()
	node.definition = definition
	node.name = graph_node_name if not graph_node_name.is_empty() else _unique_node_name(definition.node_id)
	node.position_offset = position
	add_child(node)
	node.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	node.refresh_view()
	return node


func get_spawn_position() -> Vector2:
	return scroll_offset + size * 0.5


func _print_serialized_graph() -> void:
	var data := SkillGraphSerializer.serialize_graph(self)
	print(JSON.stringify(data, "\t"))


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
		return
	connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if read_only:
		return
	record_undo()
	var from := get_node_or_null(NodePath(from_node))
	var to := get_node_or_null(NodePath(to_node))
	disconnect_node(from_node, from_port, to_node, to_port)
	if from is BaseSkillNode or to is BaseSkillNode:
		_refresh_all_skill_nodes()


func _unique_node_name(node_id: String) -> String:
	_spawn_counter += 1
	var safe_id := node_id.replace(".", "_")
	return "%s_%d" % [safe_id, _spawn_counter]
