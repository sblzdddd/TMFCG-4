extends RefCounted

## Shared layout helpers for section Trees inside an outer ScrollContainer.

const SKILL_ITEM_COLOR := Color(1.0, 0.85, 0.2)


static func prepare(tree: Tree) -> void:
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


static func apply_card_item_style(item: TreeItem, card: CardData) -> void:
	if card != null and card.type == CardData.Type.SKILL:
		item.set_custom_color(0, SKILL_ITEM_COLOR)
		item.set_icon_modulate(0, SKILL_ITEM_COLOR)
	else:
		item.clear_custom_color(0)
		item.set_icon_modulate(0, Color.WHITE)
