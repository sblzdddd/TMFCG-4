class_name CardSeatMap
extends RefCounted
## Maps holder ids to seat CardArrays for the local viewer.

const TemporaryGraveyardType := preload(
	"res://src/dsl/card_holder/temporary_graveyard.gd"
)

var left_hand: CardArray
var left_gy: CardArray
var top_hand: CardArray
var top_gy: CardArray
var bottom_gy: CardArray
var bottom_hand: CardArray
var bottom_active_hand: CardArray
var right_gy: CardArray
var right_hand: CardArray


func bind(
	p_left_hand: CardArray,
	p_left_gy: CardArray,
	p_top_hand: CardArray,
	p_top_gy: CardArray,
	p_bottom_gy: CardArray,
	p_bottom_hand: CardArray,
	p_bottom_active_hand: CardArray,
	p_right_gy: CardArray,
	p_right_hand: CardArray,
) -> void:
	left_hand = p_left_hand
	left_gy = p_left_gy
	top_hand = p_top_hand
	top_gy = p_top_gy
	bottom_gy = p_bottom_gy
	bottom_hand = p_bottom_hand
	bottom_active_hand = p_bottom_active_hand
	right_gy = p_right_gy
	right_hand = p_right_hand


func play_arrays() -> Array[CardArray]:
	return [
		left_hand, left_gy, top_hand, top_gy,
		bottom_gy, bottom_hand, bottom_active_hand, right_gy, right_hand,
	]


func find_array_with(instance_id: String) -> CardArray:
	for arr in play_arrays():
		if arr != null and arr.has_card(instance_id):
			return arr
	return null


func array_for(holder_id: String) -> CardArray:
	if holder_id.is_empty() or holder_id == Graveyard.HOLDER_ID:
		return null
	var seats := seat_uids()
	var bottom := str(seats["bottom"])
	var left := str(seats["left"])
	var top := str(seats["top"])
	var right := str(seats["right"])
	if holder_id == bottom:
		return bottom_active_hand if _local_hand_active() else bottom_hand
	if holder_id == left:
		return left_hand
	if holder_id == top:
		return top_hand
	if holder_id == right:
		return right_hand
	if holder_id == TemporaryGraveyardType.holder_id_for_player_uid(bottom):
		return bottom_gy
	if holder_id == TemporaryGraveyardType.holder_id_for_player_uid(left):
		return left_gy
	if holder_id == TemporaryGraveyardType.holder_id_for_player_uid(top):
		return top_gy
	if holder_id == TemporaryGraveyardType.holder_id_for_player_uid(right):
		return right_gy
	return null


func holder_sync_order() -> Array[String]:
	var order: Array[String] = []
	var seats := seat_uids()
	for key in ["bottom", "left", "top", "right"]:
		var uid := str(seats[key])
		if uid.is_empty():
			continue
		order.append(uid)
		order.append(TemporaryGraveyardType.holder_id_for_player_uid(uid))
	return order


func seat_uids() -> Dictionary:
	var result := {"left": "", "top": "", "right": "", "bottom": local_uid()}
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if match_state == null or PlayerDataStore.data == null:
		return result
	var seats := SeatLayout.resolve(local_uid(), match_state.order)
	result["left"] = str(seats.get("left", ""))
	result["top"] = str(seats.get("top", ""))
	result["right"] = str(seats.get("right", ""))
	return result


func local_uid() -> String:
	return "" if PlayerDataStore.data == null else PlayerDataStore.data.uid


func is_player_hand(holder_id: String) -> bool:
	return (
		not holder_id.is_empty()
		and holder_id != Deck.HOLDER_ID
		and holder_id != Graveyard.HOLDER_ID
		and not holder_id.begins_with(TemporaryGraveyardType.HOLDER_ID_PREFIX)
	)


func _local_hand_active() -> bool:
	if bottom_active_hand == null or PlayerDataStore.data == null:
		return false
	var match_state: MatchRuntimeState = null
	if RoomSession.match_controller != null:
		match_state = RoomSession.match_controller.get_state()
	if match_state == null:
		return false
	return (
		MatchPhase.is_play_phase(match_state.phase)
		and match_state.active_uid == PlayerDataStore.data.uid
	)
