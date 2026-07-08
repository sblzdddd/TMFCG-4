class_name SkillInstanceStateUtils
extends RefCounted


static func capture_inline_values(node: BaseSkillNode) -> Dictionary:
	var values := {}
	for i in node.input_specs.size():
		var spec := node._get_input_spec(i)
		if spec == null or spec.inline_widget == null:
			continue
		values[i] = spec.inline_widget.serialize()
	if node.instance_state != null:
		node.instance_state.inline_values = values
	return values


static func apply_inline_values(node: BaseSkillNode) -> void:
	if node.instance_state == null:
		return
	for key in node.instance_state.inline_values.keys():
		var index: int = int(key)
		var spec := node._get_input_spec(index)
		if spec == null or spec.inline_widget == null:
			continue
		spec.inline_widget.deserialize(node.instance_state.inline_values[key])


static func bind_inline_widget(
	spec: SkillInputSpec,
	control: Control,
	on_edit_begin: Callable = Callable()
) -> void:
	if spec == null or spec.inline_widget == null or control == null:
		return
	spec.inline_widget.apply_to_control(control)
	spec.inline_widget.bind_control(control, on_edit_begin)
