@tool
extends Container

## Centers a single child and scales it uniformly to fit this container.

@export var content_size: Vector2 = Vector2(450, 600):
	set(value):
		if content_size.is_equal_approx(value):
			return
		content_size = value
		queue_sort()


var _last_size := Vector2(-1.0, -1.0)


func _enter_tree() -> void:
	custom_minimum_size = Vector2.ZERO
	if not resized.is_connected(_request_sort):
		resized.connect(_request_sort)
	_connect_parent_resize()
	call_deferred("queue_sort")


func _exit_tree() -> void:
	if resized.is_connected(_request_sort):
		resized.disconnect(_request_sort)
	_disconnect_parent_resize()


func _ready() -> void:
	queue_sort()


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if size.is_equal_approx(_last_size):
		return
	_last_size = size
	queue_sort()


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_children()
	elif what == NOTIFICATION_RESIZED:
		queue_sort()


func _request_sort() -> void:
	queue_sort()


func _connect_parent_resize() -> void:
	var node := get_parent()
	while node is Control:
		var control := node as Control
		if not control.resized.is_connected(_request_sort):
			control.resized.connect(_request_sort)
		node = node.get_parent()


func _disconnect_parent_resize() -> void:
	var node := get_parent()
	while node is Control:
		var control := node as Control
		if control.resized.is_connected(_request_sort):
			control.resized.disconnect(_request_sort)
		node = node.get_parent()


func _layout_children() -> void:
	var fit_size := size
	if fit_size.x <= 0.0 or fit_size.y <= 0.0:
		return

	for child in get_children():
		if child is Control and (child as Control).visible:
			_fit_control(child as Control, fit_size)
			return


func _fit_control(control: Control, fit_size: Vector2) -> void:
	control.custom_minimum_size = Vector2.ZERO
	var fit_scale := minf(fit_size.x / content_size.x, fit_size.y / content_size.y)
	control.scale = Vector2.ONE * fit_scale
	control.size = content_size
	control.position = (fit_size - content_size * fit_scale) * 0.5
