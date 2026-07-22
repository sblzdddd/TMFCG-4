class_name CardArranger
extends RefCounted
## Procedural H/V positions. [param gap] is the step between card origins.


static func targets(
	rect: Rect2,
	count: int,
	gap: float,
	horizontal: bool,
	slot: Vector2,
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	# Include last card's slot so margins are equal (origins alone bias toward the start).
	var span := gap * float(count - 1) + (slot.x if horizontal else slot.y)
	var origin: Vector2
	if horizontal:
		origin = Vector2(
			rect.position.x + (rect.size.x - span) * 0.5,
			rect.position.y + (rect.size.y - slot.y) * 0.5,
		)
	else:
		origin = Vector2(
			rect.position.x + (rect.size.x - slot.x) * 0.5,
			rect.position.y + (rect.size.y - span) * 0.5,
		)
	for i in count:
		result.append(
			origin + (Vector2(gap * float(i), 0.0) if horizontal else Vector2(0.0, gap * float(i)))
		)
	return result
