extends GdUnitTestSuite
## PlayerOrder / SeatLayout unit checks.


func test_player_order_move_and_reverse() -> void:
	var order := PlayerOrder.new(["a", "b", "c", "d"])
	order.move_player("a", 1)
	assert_array(order.uids).contains_exactly(["b", "a", "c", "d"])
	order.set_order(["a", "b", "c", "d"])
	order.move_player("d", -1)
	assert_array(order.uids).contains_exactly(["a", "b", "d", "c"])
	order.set_order(["a", "b", "c"])
	order.reverse()
	assert_array(order.uids).contains_exactly(["c", "b", "a"])
	assert_str(order.next_after("c")).is_equal("b")


func test_seat_layout_clockwise_successors() -> void:
	var order := PlayerOrder.new(["self", "l", "t", "r"])
	var seats := SeatLayout.resolve("self", order)
	assert_str(seats["left"]).is_equal("l")
	assert_str(seats["top"]).is_equal("t")
	assert_str(seats["right"]).is_equal("r")

	var three := PlayerOrder.new(["self", "l", "r"])
	seats = SeatLayout.resolve("self", three)
	assert_str(seats["left"]).is_equal("l")
	assert_str(seats["top"]).is_equal("")
	assert_str(seats["right"]).is_equal("r")

	var two := PlayerOrder.new(["self", "opp"])
	seats = SeatLayout.resolve("self", two)
	assert_str(seats["top"]).is_equal("opp")
	assert_str(seats["left"]).is_equal("")
	assert_str(seats["right"]).is_equal("")

	# Reverse order → former previous sits left (anticlockwise appearance).
	order.set_order(["self", "l", "t", "r"])
	order.reverse()
	seats = SeatLayout.resolve("self", order)
	assert_str(seats["left"]).is_equal("r")
	assert_str(seats["top"]).is_equal("t")
	assert_str(seats["right"]).is_equal("l")
