@tool
extends GraphEdit
class_name SkillGraph

@export var use_new_type_names: bool = false


func _ready() -> void:
	_register_connection_types()
	if use_new_type_names:
		type_names = SkillConstants.build_type_names()
	if not connection_request.is_connected(_on_connection_request):
		connection_request.connect(_on_connection_request)


func _register_connection_types() -> void:
	for key: int in SkillConstants.TYPE_INFO.keys():
		add_valid_connection_type(key, key)
		add_valid_connection_type(-key, -key)
		add_valid_connection_type(key, -key)
		add_valid_connection_type(-key, key)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from := get_node_or_null(NodePath(from_node))
	var to := get_node_or_null(NodePath(to_node))
	if from is BaseSkillNode and to is BaseSkillNode:
		if (to as BaseSkillNode).can_connect_to(from as BaseSkillNode, from_port, to_port):
			connect_node(from_node, from_port, to_node, to_port)
		return
	connect_node(from_node, from_port, to_node, to_port)
