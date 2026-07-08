class_name SkillNodeStyleUtils extends RefCounted

static func apply_title_style(node: GraphNode, node_category: SkillNodeCategoryConstants.Category) -> void:
	var color: Color = SkillNodeCategoryConstants.TITLEBAR_COLORS.get(node_category, Color(0.4, 0.4, 0.4))

	node.remove_theme_stylebox_override("titlebar")
	var titlebar := node.get_theme_stylebox("titlebar", &"GraphNode")
	if titlebar is StyleBoxFlat:
		var styled := titlebar.duplicate() as StyleBoxFlat
		styled.bg_color = color
		styled.border_color = color.lightened(0.1)
		node.add_theme_stylebox_override("titlebar", styled)

	node.remove_theme_stylebox_override("titlebar_selected")
	var titlebar_selected := node.get_theme_stylebox("titlebar_selected", &"GraphNode")
	if titlebar_selected is StyleBoxFlat:
		var styled_selected := titlebar_selected.duplicate() as StyleBoxFlat
		styled_selected.bg_color = color
		node.add_theme_stylebox_override("titlebar_selected", styled_selected)

	var title_bar := node.get_titlebar_hbox()
	if title_bar == null:
		return

	var icon_rect: TextureRect = null
	for child in title_bar.get_children():
		if child is TextureRect:
			icon_rect = child
			break

	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_bar.add_child(icon_rect)
		title_bar.move_child(icon_rect, 0)

	if icon == null:
		icon_rect.visible = false
		return

	icon_rect.texture = icon
	icon_rect.visible = true