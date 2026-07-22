class_name DeckPanelZone
extends HBoxContainer
## Room deck profile UI: host picker, meta, foldable card grids, hover card info.

const CARD_BASE_SCENE := preload("res://definitions/prefabs/card_base.tscn")
const CARD_DISPLAY_SCALE := 0.45

@onready var deck_select: OptionButton = %DeckSelect
@onready var deck_name_label: Label = %DeckNameLabel
@onready var deck_author_label: Label = %DeckAuthorLabel
@onready var deck_desc_label: Label = %DeckDescLabel
@onready var skill_grid: GridContainer = %SkillCardGrid
@onready var standard_grid: GridContainer = %StandardCardGrid
@onready var card_info_popup: CardInfoPopup = %CardInfoPanel

var _loading := false
var _deck_paths: Array[String] = []


func _ready() -> void:
	deck_select.item_selected.connect(_on_deck_selected)
	RoomSession.room_changed.connect(_on_room_changed)
	RoomSession.deck_sync.deck_ready.connect(_on_deck_ready)
	DeckDataStore.decks_changed.connect(_refresh_deck_options)
	_refresh_deck_options()
	_on_room_changed(RoomSession.current_room)
	_on_deck_ready(RoomSession.get_resolved_deck())


func _on_room_changed(room: RoomData) -> void:
	_loading = true
	var is_host := RoomSession.is_local_host()
	if room == null:
		deck_select.visible = false
		deck_name_label.visible = true
		deck_name_label.text = "—"
		deck_author_label.text = ""
		deck_desc_label.text = ""
		_clear_grids()
		if card_info_popup != null:
			card_info_popup.hide_popup()
		_loading = false
		return

	var profile := room.deck
	deck_select.visible = is_host
	deck_name_label.visible = not is_host
	deck_name_label.text = profile.name if profile != null and not profile.name.is_empty() else "—"
	var author := profile.author if profile != null else ""
	deck_author_label.text = "作者: %s" % (author if not author.is_empty() else "—")
	deck_desc_label.text = profile.description if profile != null else ""

	if is_host:
		_select_path_in_dropdown(_host_selected_path(room))

	_loading = false


func _on_deck_ready(deck: DeckData) -> void:
	_rebuild_card_grids(deck)
	if card_info_popup != null:
		card_info_popup.hide_popup()


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
	if RoomSession.current_room != null and RoomSession.is_local_host():
		_select_path_in_dropdown(_host_selected_path(RoomSession.current_room))
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
	if _loading or not RoomSession.is_local_host():
		return
	var path := str(deck_select.get_item_metadata(index))
	if path.is_empty():
		return
	RoomSession.set_room_deck(path)


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
	card.set_card_data(card_data)
	card.hovered.connect(_on_card_base_hovered)
	card.unhovered.connect(_on_card_base_unhovered)
	return card.create_scaled_slot(CARD_DISPLAY_SCALE)


func _on_card_base_hovered(card: CardBase) -> void:
	if card_info_popup != null:
		card_info_popup.show_card(card.get_card_data())


func _on_card_base_unhovered(_card: CardBase) -> void:
	if card_info_popup != null:
		card_info_popup.hide_popup()
