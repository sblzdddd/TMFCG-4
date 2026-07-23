class_name DeckCol
extends VBoxContainer
## Shared deck preview column. Room mode syncs via RoomSession; local mode uses DeckDataStore only.

const CARD_BASE_SCENE := preload("res://definitions/prefabs/card_base.tscn")
const CARD_DISPLAY_SCALE := 0.45

@export var sync_room: bool = false

@onready var deck_select: OptionButton = %DeckSelect
@onready var deck_name_label: Label = %DeckNameLabel
@onready var deck_author_label: Label = %DeckAuthorLabel
@onready var deck_desc_label: Label = %DeckDescLabel
@onready var skill_grid: GridContainer = %SkillCardGrid
@onready var standard_grid: GridContainer = %StandardCardGrid

var _loading := false
var _deck_paths: Array[String] = []


func _ready() -> void:
	deck_select.item_selected.connect(_on_deck_selected)
	DeckDataStore.decks_changed.connect(_refresh_deck_options)
	_refresh_deck_options()
	if sync_room:
		RoomSession.room_changed.connect(_on_room_changed)
		RoomSession.match_changed.connect(func(_s) -> void: _on_room_changed(RoomSession.current_room))
		RoomSession.deck_sync.deck_ready.connect(_on_deck_ready)
		_on_room_changed(RoomSession.current_room)
		_on_deck_ready(RoomSession.get_resolved_deck())
	else:
		deck_select.visible = true
		deck_name_label.visible = false
		_load_local_selection()


func _on_room_changed(room: RoomData) -> void:
	if not sync_room:
		return
	_loading = true
	var is_host := RoomSession.is_local_host()
	var locked := RoomMatchLock.is_match_locked()
	if room == null:
		deck_select.visible = false
		deck_name_label.visible = true
		deck_name_label.text = "—"
		deck_author_label.text = ""
		deck_desc_label.text = ""
		_clear_grids()
		CardInfoPanel.hide_popup()
		_loading = false
		return

	var profile := room.deck
	deck_select.visible = is_host and not locked
	deck_name_label.visible = not is_host or locked
	deck_name_label.text = profile.name if profile != null and not profile.name.is_empty() else "—"
	var author := profile.author if profile != null else ""
	deck_author_label.text = "作者: %s" % (author if not author.is_empty() else "—")
	deck_desc_label.text = profile.description if profile != null else ""

	if is_host and not locked:
		_select_path_in_dropdown(_host_selected_path(room))

	_loading = false


func _on_deck_ready(deck: DeckData) -> void:
	if not sync_room:
		return
	_apply_deck_meta(deck)
	_rebuild_card_grids(deck)
	CardInfoPanel.hide_popup()


func _refresh_deck_options() -> void:
	_loading = true
	_deck_paths = DeckDataStore.list_paths(true)
	deck_select.clear()
	for i in _deck_paths.size():
		var path := _deck_paths[i]
		var deck := DeckDataStore.load_deck(path)
		var label := deck.name if deck != null and not deck.name.is_empty() else path.get_file().get_basename()
		if ResourceFsUtils.is_builtin_path(path):
			label = "%s (内置)" % label
		deck_select.add_item(label)
		deck_select.set_item_metadata(i, path)
	if sync_room:
		if RoomSession.current_room != null and RoomSession.is_local_host():
			_select_path_in_dropdown(_host_selected_path(RoomSession.current_room))
	elif deck_select.item_count > 0 and deck_select.selected < 0:
		deck_select.select(0)
	_loading = false


func _host_selected_path(room: RoomData) -> String:
	var sync := RoomSession.deck_sync
	if sync != null and not sync.host_source_path.is_empty():
		return sync.host_source_path
	if room.deck != null and room.deck.builtin:
		return room.deck.path
	return sync.resolved_path if sync else ""


func _select_path_in_dropdown(path: String) -> void:
	if path.is_empty():
		return
	for i in deck_select.item_count:
		if str(deck_select.get_item_metadata(i)) == path:
			deck_select.select(i)
			return


func _on_deck_selected(index: int) -> void:
	if _loading:
		return
	var path := str(deck_select.get_item_metadata(index))
	if path.is_empty():
		return
	if sync_room:
		if not RoomSession.is_local_host() or RoomMatchLock.is_match_locked():
			return
		RoomSession.set_room_deck(path)
		return
	_load_local_path(path)


func _load_local_selection() -> void:
	if deck_select.item_count <= 0:
		_clear_grids()
		deck_author_label.text = ""
		deck_desc_label.text = ""
		return
	if deck_select.selected < 0:
		deck_select.select(0)
	_load_local_path(str(deck_select.get_item_metadata(deck_select.selected)))


func _load_local_path(path: String) -> void:
	var deck := DeckDataStore.load_deck(path)
	_apply_deck_meta(deck)
	_rebuild_card_grids(deck)
	CardInfoPanel.hide_popup()


func _apply_deck_meta(deck: DeckData) -> void:
	if deck == null:
		deck_author_label.text = "作者: —"
		deck_desc_label.text = ""
		return
	var author := deck.author
	deck_author_label.text = "作者: %s" % (author if not author.is_empty() else "—")
	deck_desc_label.text = deck.description


func _rebuild_card_grids(deck: DeckData) -> void:
	_clear_grids()
	if deck == null:
		return
	for card_data in deck.cards:
		if card_data == null:
			continue
		var grid := skill_grid if card_data.type == CardEnums.Type.SKILL else standard_grid
		grid.add_child(_make_card_cell(card_data))


func _clear_grids() -> void:
	for child in skill_grid.get_children():
		child.queue_free()
	for child in standard_grid.get_children():
		child.queue_free()


func _make_card_cell(card_data: CardData) -> Control:
	var card: CardBase = CARD_BASE_SCENE.instantiate() as CardBase
	card.info_skills_only = false
	card.pass_scroll_input = true
	card.set_card_data(card_data)
	return card.create_scaled_slot(CARD_DISPLAY_SCALE)
