class_name SkillNodeSpawnMenu
extends PopupPanel

const PANEL_MIN_WIDTH := 320
const LIST_MAX_HEIGHT := 320
const LIST_ROW_HEIGHT := 24
const CATEGORY_LIST_WIDTH := 112
const CATEGORY_ICON_SCALE := 0.65
const MENU_MARGIN := 6

var _graph: SkillGraph
var _spawn_position := Vector2.ZERO
var _search: LineEdit
var _category_list: ItemList
var _node_list: ItemList
var _filter_list: ItemList
var _browse_container: HBoxContainer
var _nodes_by_category: Dictionary = {}
var _hovered_category_index := -1


func setup(graph: SkillGraph) -> void:
	_graph = graph


func _init() -> void:
	exclusive = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MENU_MARGIN)
	margin.add_theme_constant_override("margin_top", MENU_MARGIN)
	margin.add_theme_constant_override("margin_right", MENU_MARGIN)
	margin.add_theme_constant_override("margin_bottom", MENU_MARGIN)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", MENU_MARGIN)
	margin.add_child(vbox)

	_search = LineEdit.new()
	_search.placeholder_text = "搜索节点..."
	_search.custom_minimum_size.x = PANEL_MIN_WIDTH
	_search.text_changed.connect(_on_search_changed)
	_search.gui_input.connect(_on_search_gui_input)
	vbox.add_child(_search)

	_browse_container = HBoxContainer.new()
	_browse_container.add_theme_constant_override("separation", MENU_MARGIN)
	vbox.add_child(_browse_container)

	_category_list = ItemList.new()
	_category_list.custom_minimum_size = Vector2(CATEGORY_LIST_WIDTH, LIST_ROW_HEIGHT * 4)
	_category_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_category_list.max_columns = 1
	_category_list.allow_search = false
	_category_list.icon_scale = CATEGORY_ICON_SCALE
	_category_list.mouse_entered.connect(_on_category_list_mouse_entered)
	_category_list.gui_input.connect(_on_category_list_gui_input)
	_category_list.item_activated.connect(_on_category_activated)
	_browse_container.add_child(_category_list)

	_node_list = ItemList.new()
	_node_list.custom_minimum_size = Vector2(PANEL_MIN_WIDTH - CATEGORY_LIST_WIDTH, LIST_ROW_HEIGHT * 4)
	_node_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_list.max_columns = 1
	_node_list.allow_search = false
	_node_list.item_activated.connect(_on_node_item_activated)
	_browse_container.add_child(_node_list)

	_filter_list = ItemList.new()
	_filter_list.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, LIST_ROW_HEIGHT * 4)
	_filter_list.max_columns = 1
	_filter_list.allow_search = false
	_filter_list.visible = false
	_filter_list.item_activated.connect(_on_filter_item_activated)
	vbox.add_child(_filter_list)

	popup_hide.connect(_on_panel_popup_hide)


func open_at(screen_position: Vector2, spawn_position: Vector2) -> void:
	_spawn_position = spawn_position
	_filter_list.clear()
	_filter_list.visible = false
	_browse_container.visible = true
	_category_list.visible = true
	_search.text = ""
	_rebuild_category_list()
	position = Vector2i(screen_position)
	popup()
	call_deferred("_finalize_open")


func _finalize_open() -> void:
	_adjust_list_size(_category_list)
	_adjust_list_size(_node_list)
	_focus_search()


func _focus_search() -> void:
	_search.grab_focus()
	_search.caret_column = _search.text.length()


func _on_search_changed(text: String) -> void:
	var query := text.strip_edges()
	if query.is_empty():
		_filter_list.clear()
		_filter_list.visible = false
		_browse_container.visible = true
		_rebuild_category_list()
		return
	_browse_container.visible = false
	_filter_list.visible = true
	_populate_filter_list(query)


func _on_search_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var active_list := _active_list()
	match event.keycode:
		KEY_DOWN:
			if active_list != null and active_list.item_count > 0:
				active_list.grab_focus()
				active_list.select(0)
				get_viewport().set_input_as_handled()
		KEY_RIGHT:
			if _browse_container.visible and _category_list.has_focus() and _node_list.item_count > 0:
				_node_list.grab_focus()
				_node_list.select(0)
				get_viewport().set_input_as_handled()
		KEY_LEFT:
			if _browse_container.visible and _node_list.has_focus():
				_category_list.grab_focus()
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _filter_list.visible and _filter_list.item_count > 0:
				_spawn_definition(_filter_list.get_item_metadata(0))
				get_viewport().set_input_as_handled()
			elif _node_list.visible and _node_list.item_count > 0:
				var index := _node_list.get_selected_items()[0] if _node_list.is_anything_selected() else 0
				_spawn_definition(_node_list.get_item_metadata(index))
				get_viewport().set_input_as_handled()


func _on_category_list_mouse_entered() -> void:
	set_process(true)


func _on_category_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_category_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_category_hover(event.position)


func _process(_delta: float) -> void:
	if not visible or not _browse_container.visible:
		return
	var local_mouse := _category_list.get_local_mouse_position()
	if not _category_list.get_rect().has_point(local_mouse):
		return
	_update_category_hover(local_mouse)


func _update_category_hover(local_position: Vector2) -> void:
	var index := _category_list.get_item_at_position(local_position, true)
	if index < 0 or index == _hovered_category_index:
		return
	_hovered_category_index = index
	_category_list.select(index)
	_show_nodes_for_category(index)


func _on_category_activated(index: int) -> void:
	_show_nodes_for_category(index)


func _on_node_item_activated(index: int) -> void:
	_spawn_definition(_node_list.get_item_metadata(index))


func _on_filter_item_activated(index: int) -> void:
	_spawn_definition(_filter_list.get_item_metadata(index))


func _on_panel_popup_hide() -> void:
	set_process(false)
	_hovered_category_index = -1
	_nodes_by_category.clear()


func _spawn_definition(definition: Variant) -> void:
	if definition == null or _graph == null:
		return
	_graph.spawn_node(definition, _spawn_position)
	hide()


func _active_list() -> ItemList:
	if _filter_list.visible:
		return _filter_list
	if _browse_container.visible:
		if _node_list.has_focus():
			return _node_list
		return _category_list
	return null


func _show_nodes_for_category(index: int) -> void:
	if index < 0 or index >= _category_list.item_count:
		return
	_hovered_category_index = index
	var category: SkillNodeCategoryConstants.Category = _category_list.get_item_metadata(index)
	var definitions: Array = _nodes_by_category.get(category, [])
	_node_list.clear()
	for definition: SkillNodeDefinition in definitions:
		var node_index := _node_list.add_item(definition.display_name)
		_node_list.set_item_metadata(node_index, definition)
	_adjust_list_size(_node_list)


func _adjust_list_size(list: ItemList) -> void:
	var item_count := list.get_item_count()
	if item_count == 0:
		list.custom_minimum_size.y = LIST_ROW_HEIGHT * 4
		return
	list.force_update_list_size()
	var content_height := maxf(list.get_minimum_size().y, item_count * LIST_ROW_HEIGHT)
	list.custom_minimum_size.y = mini(content_height, LIST_MAX_HEIGHT)


func _rebuild_category_list() -> void:
	_nodes_by_category.clear()
	_category_list.clear()
	_node_list.clear()
	_hovered_category_index = -1
	for category: SkillNodeCategoryConstants.Category in SkillNodeCategoryConstants.ALL:
		var definitions: Array = SkillNodeRegistry.get_sorted_definitions_for_category(category)
		if definitions.is_empty():
			continue
		_nodes_by_category[category] = definitions
		var index := _category_list.add_item(SkillNodeCategoryConstants.get_display_name(category))
		_category_list.set_item_metadata(index, category)
		var icon := SkillNodeCategoryConstants.get_icon(category)
		if icon != null:
			_category_list.set_item_icon(index, icon)
	_adjust_list_size(_category_list)
	if _category_list.item_count > 0:
		_show_nodes_for_category(0)


func _populate_filter_list(query: String) -> void:
	_filter_list.clear()
	for definition: SkillNodeDefinition in SkillNodeRegistry.filter_definitions(query):
		var category_name := SkillNodeCategoryConstants.get_display_name(definition.category)
		var index := _filter_list.add_item("%s  ·  %s" % [definition.display_name, category_name])
		_filter_list.set_item_metadata(index, definition)
	_adjust_list_size(_filter_list)
