@tool
extends Window
class_name CharacterPickerDialog

signal character_selected(character: DialogicCharacter)

const TILE_WIDTH := 96
const MENU_MARGIN := 8
const FALLBACK_TEXTURE := preload("res://assets/textures/characters/Fallback.png")

static var _thumbnail_cache: Dictionary = {}

@export var _search: LineEdit
@export var _character_list: ItemList

var _all_entries: Array[Dictionary] = []


func _ready() -> void:
	close_requested.connect(hide)
	size_changed.connect(_on_size_changed)
	_search.text_changed.connect(_on_search_changed)
	_search.gui_input.connect(_on_search_gui_input)
	_character_list.icon_mode = ItemList.ICON_MODE_TOP
	_character_list.max_text_lines = 2
	_character_list.item_activated.connect(_on_item_activated)

	ResourceFsUtils.ensure_directories()
	_refresh_character_list()


func popup_picker() -> void:
	_search.text = ""
	_refresh_character_list()
	popup_centered_ratio(0.6)
	call_deferred("_focus_search")
	call_deferred("_update_grid_layout")


func _on_size_changed() -> void:
	call_deferred("_update_grid_layout")


func _focus_search() -> void:
	_search.grab_focus()
	_search.caret_column = _search.text.length()


static func is_allowed_character_path(path: String) -> bool:
	return (
		path.begins_with(ResConst.PRESET_CHARACTERS_DIR)
		or path.begins_with(ResConst.USER_CHARACTERS_DIR)
	)


func _refresh_character_list() -> void:
	_all_entries.clear()
	for path in _collect_character_paths():
		var character := load(path) as DialogicCharacter
		if character == null:
			continue
		_all_entries.append({
			"path": path,
			"display_name": _get_display_name(character),
			"character": character,
		})
	_all_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["display_name"] < b["display_name"]
	)
	_apply_filter(_search.text.strip_edges())


func _collect_character_paths() -> Array[String]:
	var paths: Array[String] = []
	paths.append_array(ResourceFsUtils.list_files(ResConst.PRESET_CHARACTERS_DIR, "dch"))
	paths.append_array(ResourceFsUtils.list_files(ResConst.USER_CHARACTERS_DIR, "dch"))
	return paths


static func _get_display_name(character: DialogicCharacter) -> String:
	var display_name := character.get_display_name_translated()
	if display_name.is_empty():
		display_name = character.get_character_name()
	if display_name.is_empty() and not character.resource_path.is_empty():
		display_name = character.resource_path.get_file().get_basename()
	return display_name


func _apply_filter(query: String) -> void:
	_character_list.clear()
	var normalized_query := query.to_lower()

	for entry: Dictionary in _all_entries:
		if not normalized_query.is_empty():
			var display_name: String = entry["display_name"]
			if not display_name.to_lower().contains(normalized_query):
				continue

		var character: DialogicCharacter = entry["character"]
		var index := _character_list.add_item(entry["display_name"])
		_character_list.set_item_metadata(index, character)
		_character_list.set_item_icon(index, _get_thumbnail(entry["path"], character))

	_update_grid_layout()


func _update_grid_layout() -> void:
	if _character_list == null:
		return

	var available_width := _character_list.size.x
	if available_width <= 0.0:
		available_width = float(size.x - MENU_MARGIN * 2)
	var columns := maxi(1, int(floor(available_width / float(TILE_WIDTH))))
	if _character_list.max_columns != columns:
		_character_list.max_columns = columns
	_character_list.force_update_list_size()


static func _get_thumbnail(path: String, character: DialogicCharacter) -> Texture2D:
	if _thumbnail_cache.has(path):
		return _thumbnail_cache[path]

	var texture := CharacterUtils.get_preview_texture(character)
	if texture == null:
		texture = FALLBACK_TEXTURE
	_thumbnail_cache[path] = texture
	return texture


func _on_search_changed(text: String) -> void:
	_apply_filter(text.strip_edges())


func _on_search_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_DOWN:
			if _character_list.item_count > 0:
				_character_list.grab_focus()
				_character_list.select(0)
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _character_list.item_count > 0:
				var index := (
					_character_list.get_selected_items()[0]
					if _character_list.is_anything_selected()
					else 0
				)
				_select_character(_character_list.get_item_metadata(index))
				get_viewport().set_input_as_handled()


func _on_item_activated(index: int) -> void:
	_select_character(_character_list.get_item_metadata(index))


func _select_character(character: DialogicCharacter) -> void:
	if character == null:
		return
	if not character.resource_path.is_empty() and not is_allowed_character_path(character.resource_path):
		push_warning("Character path outside allowed directories: %s" % character.resource_path)
		return

	character_selected.emit(character)
	hide()
