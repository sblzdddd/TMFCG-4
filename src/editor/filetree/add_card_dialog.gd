@tool
extends ConfirmationDialog
class_name AddCardDialog

signal card_created(deck_path: String, suit: CardEnums.Suit, rank: CardEnums.Rank)

@export var _suit_edit: OptionButton
@export var _value_edit: OptionButton
@export var _club_icon: Texture2D
@export var _diamond_icon: Texture2D
@export var _heart_icon: Texture2D
@export var _spade_icon: Texture2D

var _pending_deck_path: String = ""


func _ready() -> void:
	visible = false
	confirmed.connect(_on_confirmed)
	canceled.connect(_reset)
	close_requested.connect(_reset)
	CardEditUtils.populate_suit_option(
		_suit_edit, _club_icon, _diamond_icon, _heart_icon, _spade_icon
	)
	CardEditUtils.populate_value_option(_value_edit)
	_suit_edit.item_selected.connect(_on_suit_selected)


func popup_for_deck(deck_path: String) -> void:
	_pending_deck_path = deck_path
	CardEditUtils.select_suit(_suit_edit, CardEnums.Suit.CLUBS)
	_on_suit_selected(-1)
	popup_centered()


func _on_suit_selected(_index: int) -> void:
	var suit := _suit_edit.get_selected_id() as CardEnums.Suit
	var rank := _value_edit.get_selected_id() as CardEnums.Rank
	CardEditUtils.update_value_availability(_value_edit, suit, rank)


func _on_confirmed() -> void:
	if _pending_deck_path.is_empty():
		return
	var suit := _suit_edit.get_selected_id() as CardEnums.Suit
	var rank := _value_edit.get_selected_id() as CardEnums.Rank
	if not CardUtils.is_rank_valid_for_suit(suit, rank):
		push_warning("Invalid rank for selected suit.")
		call_deferred("popup_centered")
		return
	card_created.emit(_pending_deck_path, suit, rank)
	_reset()


func _reset() -> void:
	_pending_deck_path = ""
