@tool
class_name BaseSkillNode
extends GraphNode

@export var manual_update: bool = false:
	get(): return manual_update
	set(val):
		manual_update = false
		refresh_view()

@export var definition: SkillNodeDefinition
@export var instance_state: SkillNodeInstanceState

var node_category: SkillNodeCategoryConstants.Category:
	get(): return definition.category
var node_name: String:
	get(): return definition.display_name
var min_size: Vector2:
	get(): return definition.min_size
const _EMPTY_INPUT_SPECS: Array[SkillInputSpec] = []
const _EMPTY_OUTPUT_SPECS: Array[SkillSlotSpec] = []

var input_specs: Array[SkillInputSpec]:
	get():
		if definition == null:
			return _EMPTY_INPUT_SPECS
		return definition.input_slot_specs
var output_specs: Array[SkillSlotSpec]:
	get():
		if definition == null:
			return _EMPTY_OUTPUT_SPECS
		return definition.output_slot_specs

var _initialized := false

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("refresh_view")

func _ready() -> void:
	refresh_view()

func get_definition_id() -> String:
	if definition != null and not definition.node_id.is_empty():
		return definition.node_id
	if instance_state != null and not instance_state.node_id.is_empty():
		return instance_state.node_id
	return ""

func can_connect_to(from_node: BaseSkillNode, from_slot: int, to_slot: int) -> bool:
	if self == from_node:
		return false
	return SkillNodeSlotConstants.types_compatible(
		from_node.output_type(from_slot),
		input_type(to_slot)
	)

func input_type(from_slot: int) -> int: return SkillNodeSlotConstants.effective_type(_get_input_spec(from_slot), instance_state)
func output_type(from_slot: int) -> int: return SkillNodeSlotConstants.effective_type(_get_output_spec(from_slot), instance_state)

func clear_input_connections(graph: GraphEdit, to_slot: int) -> void:
	var node_path := graph.get_path_to(self)
	for conn in graph.get_connection_list():
		if NodePath(conn["to_node"]) == node_path and conn["to_port"] == to_slot:
			graph.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])

func notify_graph_changed(graph: SkillGraph) -> void:
	_resolve_definition()
	SkillPolymorphicUtils.refresh_polymorphic_types(self, graph)
	refresh_view()

func refresh_view() -> void:
	_resolve_definition()
	if not _initialized:
		_ensure_instance_state()
		_initialized = true
	if definition != null:
		title = definition.display_name
		resizable = true
	if not is_inside_tree():
		return
	SkillNodeStyleUtils.apply_title_style(self, node_category)
	SkillInstanceStateUtils.apply_inline_values(self)
	_rebuild_slots()

func _ensure_instance_state() -> void:
	if instance_state == null:
		instance_state = SkillNodeInstanceState.new()
	instance_state.node_id = get_definition_id()
	if instance_state.graph_node_name.is_empty():
		instance_state.graph_node_name = name

func _resolve_definition() -> void:
	if definition != null:
		return
	if get_script() == null:
		return
	var constants := get_script().get_script_constant_map() as Dictionary
	if constants.has("DEFINITION"):
		definition = constants["DEFINITION"]

func _rebuild_slots() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	for row_index in maxi(input_specs.size(), output_specs.size()):
		var input_spec := _get_input_spec(row_index)
		var output_spec := _get_output_spec(row_index)
		var left_type := SkillNodeSlotConstants.effective_type(input_spec, instance_state)
		var right_type := SkillNodeSlotConstants.effective_type(output_spec, instance_state)
		SkillSlotUtils.build_slot_row(self, row_index, input_spec, output_spec, left_type, right_type)

		if input_spec == null and output_spec == null:
			break
		var row := HBoxContainer.new()

		var left_widget = input_spec.build_widget() if input_spec != null else null
		if left_widget != null:
			SkillInstanceStateUtils.bind_inline_widget(
				input_spec,
				left_widget,
				Callable(self, "_begin_inline_edit_undo")
			)
			row.add_child(left_widget)
		else:
			row.add_child(SkillSlotUtils.make_row_filler())

		var right_widget := output_spec.build_widget() if output_spec != null else null
		if right_widget != null:
			row.add_child(right_widget)

		add_child(row)
	custom_minimum_size = min_size
	reset_size()

func _get_input_spec(row_index: int) -> SkillInputSpec:
	if row_index < 0 or row_index >= input_specs.size():
		return null
	return input_specs[row_index]

func _get_output_spec(row_index: int) -> SkillSlotSpec:
	if row_index < 0 or row_index >= output_specs.size():
		return null
	return output_specs[row_index]


func capture_instance_state() -> Dictionary:
	SkillInstanceStateUtils.capture_inline_values(self)
	return {
		"polymorphic_types": instance_state.polymorphic_types.duplicate(true),
		"inline_values": instance_state.inline_values.duplicate(true),
	}


func _begin_inline_edit_undo() -> void:
	var graph := get_parent()
	if graph is SkillGraph:
		(graph as SkillGraph).record_undo()


func apply_instance_state_snapshot(snapshot: Dictionary) -> void:
	instance_state.polymorphic_types = snapshot.get("polymorphic_types", {}).duplicate(true)
	instance_state.inline_values = snapshot.get("inline_values", {}).duplicate(true)
	refresh_view()
