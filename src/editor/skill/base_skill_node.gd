@tool
class_name BaseSkillNode
extends GraphNode

@export var node_category: SkillNodeCategory.Category = SkillNodeCategory.Category.EVENT:
	set(value):
		node_category = value
		_apply_category_style()

@export var node_name: String:
	set(value):
		node_name = value
		title = node_name

@export var icon: Texture2D:
	set(value):
		icon = value
		_update_icon()

@export var input_slot_specs: Array[SkillInputSpec] = []
@export var output_slot_specs: Array[SkillSlotSpec] = []

var _title_icon_rect: TextureRect = null
var titlebar_style: StyleBoxFlat = null
var titlebar_selected_style: StyleBoxFlat = StyleBoxFlat.new()

@export var manual_update: bool = false:
	get(): return manual_update
	set(val):
		titlebar_style = null
		titlebar_selected_style = null
		_rebuild_all()
		manual_update = false

@export var min_size: Vector2 = Vector2(200, 50)

func info() -> void:
	return

func _init_style() -> void:
	if titlebar_style != null and titlebar_selected_style != null: return
	var titlebar := get_theme_stylebox("titlebar", &"GraphNode")
	if titlebar is StyleBoxFlat:
		titlebar_style = titlebar.duplicate()

	var titlebar_selected := get_theme_stylebox("titlebar_selected", &"GraphNode")
	if titlebar_selected is StyleBoxFlat:
		titlebar_selected_style = titlebar_selected.duplicate()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_rebuild_all")

func _ready() -> void:
	_rebuild_all()

func get_input_slot_type(slot_index: int) -> int:
	var spec := _get_input_spec(slot_index)
	if spec == null:
		return SkillConstants.PortType.EVENT
	return spec.type

func get_output_slot_type(slot_index: int) -> int:
	var spec := _get_output_spec(slot_index)
	if spec == null:
		return SkillConstants.PortType.EVENT
	return spec.type

func can_connect_to(from_node: BaseSkillNode, from_slot: int, to_slot: int) -> bool:
	return SkillConstants.types_compatible(
		from_node.get_output_slot_type(from_slot),
		get_input_slot_type(to_slot)
	)

func _rebuild_all() -> void:
	info()
	if not is_inside_tree(): return
	_update_icon()
	_apply_category_style()
	_rebuild_slots()

func _update_icon() -> void:
	var title_bar := get_titlebar_hbox()
	if title_bar == null: return

	if _title_icon_rect == null or not is_instance_valid(_title_icon_rect):
		_title_icon_rect = TextureRect.new()
		_title_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_title_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_bar.add_child(_title_icon_rect)
		title_bar.move_child(_title_icon_rect, 0)
	elif _title_icon_rect.get_parent() != title_bar:
		title_bar.add_child(_title_icon_rect)
		title_bar.move_child(_title_icon_rect, 0)

	if _title_icon_rect == null or not is_instance_valid(_title_icon_rect):
		return
	_title_icon_rect.texture = icon
	_title_icon_rect.visible = icon != null

func _apply_category_style() -> void:
	_init_style()
	var color: Color = SkillNodeCategory.TITLEBAR_COLORS.get(node_category, Color(0.4, 0.4, 0.4))
	titlebar_style.bg_color = color
	titlebar_style.border_color =  color.lightened(0.1)
	titlebar_selected_style.bg_color = color
	add_theme_stylebox_override("titlebar", titlebar_style.duplicate())
	add_theme_stylebox_override("titlebar_selected", titlebar_selected_style.duplicate())

func _rebuild_slots() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	for row_index in maxi(input_slot_specs.size(), output_slot_specs.size()):
		var input_spec := _get_input_spec(row_index)
		var output_spec := _get_output_spec(row_index)
		_configure_slot(row_index, input_spec, output_spec)
		var row := _build_row_ui(input_spec, output_spec)
		if row != null: add_child(row)
	custom_minimum_size = min_size
	reset_size()

func _get_input_spec(row_index: int) -> SkillInputSpec:
	if row_index < 0 or row_index >= input_slot_specs.size():
		return null
	return input_slot_specs[row_index]

func _get_output_spec(row_index: int) -> SkillSlotSpec:
	if row_index < 0 or row_index >= output_slot_specs.size():
		return null
	return output_slot_specs[row_index]

func _configure_slot(row_index: int, input_spec: SkillInputSpec, output_spec: SkillSlotSpec) -> void:
	var left_type := input_spec.type if input_spec != null else 0
	var right_type := output_spec.type if output_spec != null else 0
	var left_enabled := input_spec != null and input_spec.enable_port
	var right_enabled := output_spec != null and output_spec.enable_port
	set_slot(row_index,
		left_enabled, left_type, SkillConstants.get_color(left_type),
		right_enabled, right_type, SkillConstants.get_color(right_type),
		SkillConstants.get_icon(left_type), SkillConstants.get_icon(right_type)
	)

func _build_row_ui(input_spec: SkillInputSpec, output_spec: SkillSlotSpec) -> Control:
	var row := HBoxContainer.new()
	var left_widget: Control = null
	if input_spec != null:
		left_widget = input_spec.build_widget()
		if left_widget != null:
			row.add_child(left_widget)

	var right_widget: Control = null
	if output_spec != null:
		right_widget = output_spec.build_widget()

	if right_widget != null:
		if left_widget == null and _is_left_spacer(input_spec):
			var filler := Control.new()
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(filler)
			if right_widget is Label:
				(right_widget as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(right_widget)

	if row.get_child_count() > 0:
		return row
	return null

func _is_left_spacer(input_spec: SkillInputSpec) -> bool:
	if input_spec == null:
		return true
	return not input_spec.enable_port and input_spec.label.is_empty() and input_spec.inline_widget == null

