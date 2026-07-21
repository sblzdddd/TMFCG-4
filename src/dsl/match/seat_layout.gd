class_name SeatLayout
extends RefCounted
## Maps play-order successors of the local player to combat seat slots.

enum Seat {
	NONE = 0,
	LEFT = 1,
	TOP = 2,
	RIGHT = 3,
	BOTTOM = 4,
}


## Returns `{ "left": uid, "top": uid, "right": uid }` (empty string = vacant).
static func resolve(local_uid: String, order: PlayerOrder) -> Dictionary:
	var result := {"left": "", "top": "", "right": ""}
	if order == null or order.is_empty() or local_uid.is_empty():
		return result
	if not order.has(local_uid):
		return result

	var successors: Array[String] = []
	var cursor := local_uid
	for _i in order.size() - 1:
		cursor = order.next_after(cursor)
		if cursor.is_empty() or cursor == local_uid:
			break
		successors.append(cursor)

	match successors.size():
		1:
			result["top"] = successors[0]
		2:
			result["left"] = successors[0]
			result["right"] = successors[1]
		_:
			if successors.size() >= 3:
				result["left"] = successors[0]
				result["top"] = successors[1]
				result["right"] = successors[2]
	return result


## Seat of [param active_uid] relative to [param local_uid] in [param order].
static func seat_of(local_uid: String, active_uid: String, order: PlayerOrder) -> Seat:
	if active_uid.is_empty() or local_uid.is_empty():
		return Seat.NONE
	if active_uid == local_uid:
		return Seat.BOTTOM
	var seats := resolve(local_uid, order)
	if seats["left"] == active_uid:
		return Seat.LEFT
	if seats["top"] == active_uid:
		return Seat.TOP
	if seats["right"] == active_uid:
		return Seat.RIGHT
	return Seat.NONE


## Shortest steps around the table ring BOTTOM → LEFT → TOP → RIGHT.
static func ring_distance(from_seat: Seat, to_seat: Seat) -> int:
	if from_seat == Seat.NONE or to_seat == Seat.NONE:
		return 3
	var ring: Array[int] = [Seat.BOTTOM, Seat.LEFT, Seat.TOP, Seat.RIGHT]
	var ia := ring.find(from_seat)
	var ib := ring.find(to_seat)
	if ia < 0 or ib < 0:
		return 3
	var d := absi(ia - ib)
	return mini(d, ring.size() - d)


static func dim_brightness(distance: int) -> float:
	match distance:
		0:
			return 1.0
		1:
			return 0.72
		2:
			return 0.48
		_:
			return 0.36
