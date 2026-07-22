class_name CardHolder
extends RefCounted

enum Kind {
	PLAYER_HAND = 0,
	DECK = 1,
	GRAVEYARD = 2,
	TEMPORARY_GRAVEYARD = 3,
}

signal cards_changed()
signal cards_transferred(
	from: CardHolder,
	to: CardHolder,
	cards: Array,
	mark_hidden: bool,
	ignore_passives: bool,
)

var kind: Kind
var holder_id: String = ""
var _cards: Array[Card] = []


func _init(
	p_kind: Kind = Kind.DECK,
	p_holder_id: String = "",
	p_cards: Array[Card] = [],
) -> void:
	kind = p_kind
	holder_id = p_holder_id
	_cards = p_cards.duplicate()


func get_size() -> int:
	return _cards.size()


func get_card(index: int) -> Card:
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index]


func get_cards(range_start: int, range_end: int) -> Array[Card]:
	if range_start < 0 or range_end > _cards.size() - 1 or range_start > range_end:
		return []
	return _cards.slice(range_start, range_end + 1) as Array[Card]


func get_all_cards() -> Array[Card]:
	return _cards.duplicate()


func take_random(count: int) -> Array[Card]:
	if count <= 0 or _cards.is_empty():
		return []
	var pool := _cards.duplicate()
	pool.shuffle()
	var taken: Array[Card] = []
	var n := mini(count, pool.size())
	for i in n:
		taken.append(pool[i])
	return taken


func add_cards(cards: Array[Card], emit_changed: bool = true) -> void:
	for card in cards:
		_cards.append(card)
	if emit_changed and not cards.is_empty():
		cards_changed.emit()


func insert_card(card: Card, index: int, emit_changed: bool = true) -> void:
	var clamped := clampi(index, 0, _cards.size())
	_cards.insert(clamped, card)
	if emit_changed:
		cards_changed.emit()


func remove_cards(cards: Array[Card], emit_changed: bool = true) -> Array[Card]:
	var removed: Array[Card] = []
	for card in cards:
		var index := _cards.find(card)
		if index >= 0:
			removed.append(_cards[index])
			_cards.remove_at(index)
	if emit_changed and not removed.is_empty():
		cards_changed.emit()
	return removed


func transfer_to(
	dest: CardHolder,
	cards: Array[Card],
	mark_hidden: bool = false,
	ignore_passives: bool = false,
) -> Array[Card]:
	if dest == null or cards.is_empty():
		return []
	var moved := remove_cards(cards, false)
	if moved.is_empty():
		return []
	if mark_hidden:
		for card in moved:
			if dest.kind == Kind.PLAYER_HAND:
				card.restrict_visibility_to([dest.holder_id])
			else:
				card.restrict_visibility_to([])
	dest.add_cards(moved, false)
	if dest.kind != Kind.DECK:
		dest.sort_by_rank()
	cards_changed.emit()
	dest.cards_changed.emit()
	cards_transferred.emit(self, dest, moved, mark_hidden, ignore_passives)
	dest.cards_transferred.emit(self, dest, moved, mark_hidden, ignore_passives)
	return moved


func sort_by_rank(wild_rank: CardEnums.Rank = CardEnums.Rank.NONE) -> void:
	CardRankSort.sort_cards(_cards, wild_rank)


func to_dict() -> Dictionary:
	var card_dicts: Array = []
	for card in _cards:
		card_dicts.append(card.to_dict())
	return {
		"kind": Kind.find_key(kind),
		"holderId": holder_id,
		"cards": card_dicts,
	}


func to_dict_for_viewer(viewer_uid: String) -> Dictionary:
	var card_dicts: Array = []
	for card in _cards:
		card_dicts.append(card.to_dict_for_viewer(viewer_uid))
	return {
		"kind": Kind.find_key(kind),
		"holderId": holder_id,
		"cards": card_dicts,
	}


static func cards_from_dict(dict: Dictionary) -> Array[Card]:
	var result: Array[Card] = []
	var raw_cards: Variant = dict.get("cards", [])
	if raw_cards is Array:
		for item in raw_cards:
			if item is Dictionary:
				result.append(Card.from_dict(item))
	return result


static func kind_from_name(name: String) -> Kind:
	match name.to_upper():
		"PLAYER_HAND":
			return Kind.PLAYER_HAND
		"GRAVEYARD":
			return Kind.GRAVEYARD
		"TEMPORARY_GRAVEYARD":
			return Kind.TEMPORARY_GRAVEYARD
		_:
			return Kind.DECK
