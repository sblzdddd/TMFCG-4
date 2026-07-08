class_name SkillNodeRegistry
extends RefCounted

const DEFINITIONS_ROOT := "res://src/editor/skill/definitions/"

static var _by_id: Dictionary = {}
static var _by_category: Dictionary = {}
static var _initialized := false


static func initialize() -> void:
	if _initialized:
		return
	_by_id.clear()
	_by_category.clear()
	_scan_dir(DEFINITIONS_ROOT)
	_initialized = true


static func get_definition(node_id: String) -> SkillNodeDefinition:
	initialize()
	return _by_id.get(node_id)


static func get_definitions_for_category(category: SkillNodeCategoryConstants.Category) -> Array:
	initialize()
	return _by_category.get(category, [])


static func build_tree(tree: Tree) -> void:
	initialize()
	tree.clear()
	var root := tree.create_item()
	for category: SkillNodeCategoryConstants.Category in SkillNodeCategoryConstants.ALL:
		var defs: Array = _by_category.get(category, [])
		if defs.is_empty():
			continue
		var category_item := tree.create_item(root)
		category_item.set_text(0, SkillNodeCategoryConstants.get_display_name(category))
		category_item.set_icon(0, SkillNodeCategoryConstants.get_icon(category))
		category_item.set_selectable(0, false)
		defs.sort_custom(func(a: SkillNodeDefinition, b: SkillNodeDefinition) -> bool:
			return a.display_name < b.display_name
		)
		for definition: SkillNodeDefinition in defs:
			var item := tree.create_item(category_item)
			item.set_text(0, definition.display_name)
			item.set_metadata(0, definition.node_id)


static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name.is_empty():
			break
		if dir.current_is_dir() and not entry_name.begins_with("."):
			_scan_dir(path.path_join(entry_name))
			continue
		if not entry_name.ends_with(".tres"):
			continue
		var definition := load(path.path_join(entry_name)) as SkillNodeDefinition
		if definition == null or definition.node_id.is_empty():
			continue
		_by_id[definition.node_id] = definition
		if not _by_category.has(definition.category):
			_by_category[definition.category] = []
		_by_category[definition.category].append(definition)
	dir.list_dir_end()
