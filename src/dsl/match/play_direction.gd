class_name PlayDirection
extends RefCounted

enum Direction {
	CLOCKWISE,
	COUNTER_CLOCKWISE,
}


static func reverse(direction: Direction) -> Direction:
	if direction == Direction.CLOCKWISE:
		return Direction.COUNTER_CLOCKWISE
	return Direction.CLOCKWISE
