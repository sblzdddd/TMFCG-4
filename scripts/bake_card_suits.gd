extends SceneTree
## Bakes 52 transparent suit-layer PNGs (4 suits × 13 ranks) at 300×400.
## Must NOT use --headless (dummy renderer cannot read viewport textures).
## Run: DISPLAY=:1 godot --path . --script res://scripts/bake_card_suits.gd

const OUT_DIR := "res://assets/textures/cards/suits/"
const OUT_SIZE := Vector2i(600, 800)
const BAKE_SHADER := preload("res://src/shaders/card_suit_bake.gdshader")
const PARTS_TEX := preload("res://assets/textures/cards/tex_card_parts.png")
const JQK_TEX := preload("res://assets/textures/cards/tex_card_jqk.png")

const SUIT_NAMES := ["club", "diamond", "heart", "spade"]
const VALUE_NAMES := ["", "a", "2", "3", "4", "5", "6", "7", "8", "9", "10", "j", "q", "k"]

const TINT1 := Color(0.5921569, 0.2705882, 0.2)
const TINT2 := Color(0.7176471, 0.345098, 0.2196078)
const TINT3 := Color(1, 1, 1)

var _viewport: SubViewport
var _rect: ColorRect
var _material: ShaderMaterial


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error(
			"bake_card_suits requires a real renderer. Do not pass --headless.\n"
			+ "Run: DISPLAY=:1 godot --path . --script res://scripts/bake_card_suits.gd"
		)
		quit(1)
		return
	call_deferred("_run_bake")


func _run_bake() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	_material = ShaderMaterial.new()
	_material.shader = BAKE_SHADER
	_material.set_shader_parameter("partsTex", PARTS_TEX)
	_material.set_shader_parameter("JQKTex", JQK_TEX)
	_material.set_shader_parameter("tint1", TINT1)
	_material.set_shader_parameter("tint2", TINT2)
	_material.set_shader_parameter("tint3", TINT3)

	_viewport = SubViewport.new()
	_viewport.size = OUT_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.disable_3d = true
	RenderingServer.set_default_clear_color(Color("ede1ce00"))
	root.add_child(_viewport)

	_rect = ColorRect.new()
	_rect.size = Vector2(OUT_SIZE)
	_rect.color = Color("ede1ce00")
	_rect.material = _material
	_viewport.add_child(_rect)

	# Hide the game window; we only need the SubViewport.
	if DisplayServer.window_can_draw(0):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	print("Baking suit layers to %s ..." % OUT_DIR)

	var done := 0
	for suit in range(4):
		for value in range(1, 14):
			_material.set_shader_parameter("suit", suit)
			_material.set_shader_parameter("value", value)
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

			# Let the viewport draw with the new uniforms.
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw

			var tex := _viewport.get_texture()
			if tex == null:
				push_error("Viewport texture is null")
				quit(1)
				return

			var img: Image = tex.get_image()
			if img == null or img.is_empty():
				push_error("Failed to read viewport texture (image empty)")
				quit(1)
				return

			var path := OUT_DIR + "%s_%s.png" % [SUIT_NAMES[suit], VALUE_NAMES[value]]
			var err := img.save_png(path)
			if err != OK:
				push_error("Failed to save %s (error %d)" % [path, err])
				quit(1)
				return

			done += 1
			print("  [%d/52] %s" % [done, path])

	print("Done. Baked %d suit layers." % done)
	quit(0)
