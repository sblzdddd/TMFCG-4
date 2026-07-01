@tool
extends Path2D
class_name CurvedText


@export var text: String = "Kasodani Kyouko":
	set(value):
		if text != value:
			text = value
			queue_redraw()


@export var label_settings: LabelSettings:
	set(value):
		if is_instance_valid(label_settings) and label_settings.changed.is_connected(queue_redraw):
			label_settings.changed.disconnect(queue_redraw)

		label_settings = value

		if is_instance_valid(label_settings):
			label_settings.changed.connect(queue_redraw)


@export var character_spacing: float = 0.0:
	set(value):
		if character_spacing != value:
			character_spacing = value
			queue_redraw()


@export_group("Autosize")
@export var autosize_enabled: bool = true:
	set(value):
		if autosize_enabled != value:
			autosize_enabled = value
			queue_redraw()


@export var autosize_base_size: int = 60:
	set(value):
		if autosize_base_size != value:
			autosize_base_size = value
			queue_redraw()


@export var autosize_multiplier: float = 2.17:
	set(value):
		if autosize_multiplier != value:
			autosize_multiplier = value
			queue_redraw()


@export var autosize_threshold_length: int = 13:
	set(value):
		if autosize_threshold_length != value:
			autosize_threshold_length = value
			queue_redraw()


@export var autosize_base_y: float = 0.0:
	set(value):
		if autosize_base_y != value:
			autosize_base_y = value
			queue_redraw()


@export var autosize_y_ratio: float = -0.265:
	set(value):
		if autosize_y_ratio != value:
			autosize_y_ratio = value
			queue_redraw()


var _line = TextLine.new()


func _get_autosized_font_size() -> int:
	var length_delta := text.length() - autosize_threshold_length
	return maxi(int(autosize_base_size - maxf(length_delta, 0) * autosize_multiplier), 1)


func _get_autosize_y_offset(font_size: int) -> float:
	var size_delta := autosize_base_size - font_size
	return autosize_base_y + float(size_delta) * autosize_y_ratio


func _get_text_length(glyphs: Array) -> float:
	var length := 0.0
	var last_advance_index := -1

	for i in glyphs.size():
		if glyphs[i].get("advance", 0.0) > 0.0:
			last_advance_index = i

	for i in glyphs.size():
		var advance: float = glyphs[i].get("advance", 0.0)
		length += advance
		if advance > 0.0 and i < last_advance_index:
			length += character_spacing

	return length


func _draw() -> void:
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var font_color = Color.WHITE
	var outline_size := 0
	var outline_color := Color.WHITE

	if is_instance_valid(label_settings):
		font = label_settings.font
		font_size = label_settings.font_size
		font_color = label_settings.font_color
		outline_size = label_settings.outline_size
		outline_color = label_settings.outline_color

	if autosize_enabled:
		font_size = _get_autosized_font_size()

	var autosize_y_offset := 0.0
	if autosize_enabled:
		autosize_y_offset = _get_autosize_y_offset(font_size)

	# Clear the line and add the new string
	_line.clear()
	_line.add_string(text, font, font_size)
	# Get the primary TextServer
	var ts = TextServerManager.get_primary_interface()
	# And get the glyph information from the line
	var glyphs = ts.shaped_text_get_glyphs(_line.get_rid())

	var text_length := _get_text_length(glyphs)
	var offset := maxf((curve.get_baked_length() - text_length) * 0.5, 0.0)

	var last_advance_index := -1
	for i in glyphs.size():
		if glyphs[i].get("advance", 0.0) > 0.0:
			last_advance_index = i

	for i in glyphs.size():
		var glyph_data: Dictionary = glyphs[i]
		var trans = curve.sample_baked_with_rotation(offset)
		if autosize_y_offset != 0.0:
			trans.origin += trans.y * autosize_y_offset
		draw_set_transform_matrix(trans)
		if outline_size > 0:
			ts.font_draw_glyph_outline(
				glyph_data["font_rid"], get_canvas_item(), font_size, outline_size,
				Vector2.ZERO, glyph_data["index"], outline_color, 2.0
			)
		ts.font_draw_glyph(
			glyph_data["font_rid"], get_canvas_item(), font_size,
			Vector2.ZERO, glyph_data["index"], font_color, 2.0
		)

		var advance: float = glyph_data.get("advance", 0.0)
		offset += advance
		if advance > 0.0 and i < last_advance_index:
			offset += character_spacing
