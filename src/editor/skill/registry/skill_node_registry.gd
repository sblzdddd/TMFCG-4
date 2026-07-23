class_name SkillNodeRegistry
extends RefCounted

static var _by_id: Dictionary = {}
static var _by_category: Dictionary = {}
static var _initialized := false


static func initialize(force: bool = false) -> void:
	if _initialized and not force:
		return
	_by_id.clear()
	_by_category.clear()
	_scan_dir(SkillNodeDefinition.DEFINITIONS_ROOT)
	# Only lock if we found definitions, or the root is readable and genuinely empty.
	# Avoid permanently caching a failed early scan (e.g. @tool _ready before FS is ready).
	if not _by_id.is_empty() or _directory_readable(SkillNodeDefinition.DEFINITIONS_ROOT):
		_initialized = true


static func get_definition(node_id: String) -> SkillNodeDefinition:
	initialize()
	return _by_id.get(node_id)


static func get_definitions_for_category(category: SkillNodeCategoryConstants.Category) -> Array:
	initialize()
	return _by_category.get(category, [])


static func get_sorted_definitions_for_category(category: SkillNodeCategoryConstants.Category) -> Array:
	return _sort_definitions(get_definitions_for_category(category))


static func filter_definitions(query: String) -> Array:
	initialize()
	var normalized := query.strip_edges().to_lower()
	if normalized.is_empty():
		return []
	var matches: Array = []
	for definition: SkillNodeDefinition in _by_id.values():
		if definition.display_name.to_lower().contains(normalized):
			matches.append(definition)
			continue
		if definition.node_id.to_lower().contains(normalized):
			matches.append(definition)
	return _sort_definitions(matches)


static func build_tree(tree: Tree) -> void:
	initialize()
	tree.clear()
	var root := tree.create_item()
	for category: SkillNodeCategoryConstants.Category in SkillNodeCategoryConstants.ALL:
		var defs: Array = get_sorted_definitions_for_category(category)
		if defs.is_empty():
			continue
		var category_item := tree.create_item(root)
		category_item.set_text(0, SkillNodeCategoryConstants.get_display_name(category))
		category_item.set_icon(0, SkillNodeCategoryConstants.get_icon(category))
		category_item.set_selectable(0, false)
		for definition: SkillNodeDefinition in defs:
			var item := tree.create_item(category_item)
			item.set_text(0, definition.display_name)
			item.set_metadata(0, definition.node_id)


static func _sort_definitions(definitions: Array) -> Array:
	var sorted: Array = definitions.duplicate()
	sorted.sort_custom(func(a: SkillNodeDefinition, b: SkillNodeDefinition) -> bool:
		return a.display_name < b.display_name
	)
	return sorted


static func _directory_readable(path: String) -> bool:
	if path.begins_with("res://"):
		return not ResourceLoader.list_directory(path).is_empty() or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)
		)
	return DirAccess.open(path) != null


static func _scan_dir(path: String) -> void:
	# Prefer ResourceLoader for res:// (works in editor + exported packs).
	if path.begins_with("res://"):
		_scan_dir_resource_loader(path)
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while not entry_name.is_empty():
		if dir.current_is_dir() and not entry_name.begins_with("."):
			_scan_dir(path.path_join(entry_name))
		elif entry_name.get_extension().to_lower() == "tres":
			_register_definition(path.path_join(entry_name))
		entry_name = dir.get_next()
	dir.list_dir_end()


static func _scan_dir_resource_loader(path: String) -> void:
	for entry_name in ResourceLoader.list_directory(path):
		if entry_name.begins_with("."):
			continue
		if entry_name.ends_with("/"):
			_scan_dir_resource_loader(path.path_join(entry_name.trim_suffix("/")))
			continue
		if entry_name.get_extension().to_lower() != "tres":
			continue
		_register_definition(path.path_join(entry_name))


static func _register_definition(definition_path: String) -> void:
	var definition := load(definition_path) as SkillNodeDefinition
	if definition == null or definition.node_id.is_empty():
		return
	if not definition.has_node_script():
		push_warning(
			"SkillNodeDefinition '%s' is missing node script at %s."
			% [definition.node_id, definition.get_resolved_node_script_path()]
		)
	_by_id[definition.node_id] = definition
	if not _by_category.has(definition.category):
		_by_category[definition.category] = []
	_by_category[definition.category].append(definition)
