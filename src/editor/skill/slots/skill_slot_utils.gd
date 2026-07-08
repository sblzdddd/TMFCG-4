class_name SkillSlotUtils
extends RefCounted

static func make_row_filler() -> Control:
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return filler


static func make_label(text: String, horizontal_size_flags: Control.SizeFlags) -> Label:
	var label := Label.new()
	label.custom_minimum_size.y = SkillNodeSlotConstants.ROW_MIN_HEIGHT
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = horizontal_size_flags
	return label

static func build_slot_row(
	graph_node: GraphNode,
	row_index: int,
	input_spec: SkillInputSpec,
	output_spec: SkillSlotSpec,
	left_type: int = SkillNodeSlotConstants.PortType.UNDEFINED,
	right_type: int = SkillNodeSlotConstants.PortType.UNDEFINED
) -> void:
	if left_type == SkillNodeSlotConstants.PortType.UNDEFINED:
		left_type = input_spec.type if input_spec != null else SkillNodeSlotConstants.PortType.UNDEFINED
	if right_type == SkillNodeSlotConstants.PortType.UNDEFINED:
		right_type = output_spec.type if output_spec != null else SkillNodeSlotConstants.PortType.UNDEFINED
	var left_enabled := left_type != SkillNodeSlotConstants.PortType.UNDEFINED
	var right_enabled := right_type != SkillNodeSlotConstants.PortType.UNDEFINED
	var left_graph_type := SkillNodeSlotConstants.graph_port_type(left_type)
	var right_graph_type := SkillNodeSlotConstants.graph_port_type(right_type)
	graph_node.set_slot(row_index,
		left_enabled, left_graph_type, SkillNodeSlotConstants.get_color(left_type),
		right_enabled, right_graph_type, SkillNodeSlotConstants.get_color(right_type),
		SkillNodeSlotConstants.get_icon(left_type), SkillNodeSlotConstants.get_icon(right_type)
	)

