extends RefCounted

## Shared layout helpers for section Trees inside an outer ScrollContainer.


static func prepare(tree: Tree) -> void:
	tree.hide_root = false
	tree.scroll_vertical_enabled = false
	tree.scroll_horizontal_enabled = false
	tree.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


static func fit_height(tree: Tree) -> void:
	tree.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var root := tree.get_root()
	if root == null:
		tree.custom_minimum_size.y = 0
		return

	var last: TreeItem = root
	var cursor := root.get_next_visible()
	while cursor:
		last = cursor
		cursor = cursor.get_next_visible()

	var area := tree.get_item_area_rect(last)
	var bottom := 0
	var panel := tree.get_theme_stylebox("panel")
	if panel:
		bottom = int(panel.get_margin(SIDE_BOTTOM))
	tree.custom_minimum_size.y = maxi(ceili(area.position.y + area.size.y) + bottom, 0)
