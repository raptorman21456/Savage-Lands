extends SceneTree

# The 8-bit look, as checks: every PNG in assets/ is real pixel art (few colours, hard edges), the screen effects that would be smooth
# (vignettes, gradients, circles) are stepped, the battle screen's panels are cut-cornered and unsmoothed, the whole game's text is in the
# pixel font, and Berserk's red vignette shows only while it lasts.

# Art that is translucent on purpose (a ghost, glass, water, a spirit, the toggle's glow) -- everything else must have hard 0/255 edges.
const TRANSLUCENT_ON_PURPOSE := ["shield_phantom.png", "toggle_off.png", "toggle_on.png", "enemy_fae.png", "fountain.png", "potion.png"]
const MAX_COLOURS := 64
const MAX_SEMI_PERCENT := 8.0

var problems: Array = []

func _scan(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			_audit("%s/%s" % [dir, f], f)
	for d in DirAccess.get_directories_at(dir):
		_scan("%s/%s" % [dir, d])

func _audit(path: String, file: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		problems.append(path + " (unreadable)")
		return
	img.convert(Image.FORMAT_RGBA8)
	var colors := {}
	var semi := 0
	var drawn := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			drawn += 1
			if c.a < 0.99:
				semi += 1
			else:
				colors[c.to_rgba32()] = true
	var semi_pct: float = 100.0 * semi / maxf(1.0, drawn)
	if colors.size() > MAX_COLOURS:
		problems.append("%s has %d colours" % [path, colors.size()])
	if semi_pct > MAX_SEMI_PERCENT and not TRANSLUCENT_ON_PURPOSE.has(file) and not file.begins_with("building_") and file != "castle.png":
		problems.append("%s is %.0f%% semi-transparent (anti-aliased edges?)" % [path, semi_pct])

func _init() -> void:
	# --- the art ---
	_scan("res://assets")
	print("every PNG in assets/ is pixel art -- at most %d colours, hard edges (translucency only where it is meant): problems=%s (expected [])" % [MAX_COLOURS, problems])

	var fx = load("res://scripts/PixelFx.gd")
	var kit = load("res://scripts/PixelKit.gd")
	var style = load("res://scripts/BattleStyle.gd")

	# --- stepped effects ---
	var tex: ImageTexture = fx.vignette(Color(1, 0, 0), 0.6, 64, 36, 4, 0.45, true)
	var img: Image = tex.get_image()
	var alphas := {}
	for y in img.get_height():
		for x in img.get_width():
			alphas[snappedf(img.get_pixel(x, y).a, 0.0001)] = true
	print("a vignette has only %d alpha steps for 4 steps (+ clear): %s (expected 5 values: 0, .15, .3, .45, .6)" % [alphas.size(), alphas.keys()])
	print("...clear in the middle, strongest at the corners: centre=%.2f corner=%.2f (expected 0.00, 0.60)" % [img.get_pixel(32, 18).a, img.get_pixel(0, 0).a])
	print("...and the same on the opposite corner (symmetrical-ish, the dither aside): %.2f / %.2f (expected both about 0.6)" % [img.get_pixel(0, 0).a, img.get_pixel(63, 35).a])
	var banded: Image = fx.bands(Color(0, 0.22, 0.3), Color(0.02, 0.18, 0.1), 9).get_image()
	print("a gradient is flat bands: %d x %d, %d different colours (expected 1 x 9, 9)" % [banded.get_width(), banded.get_height(), _distinct(banded)])

	# --- the cut corners ---
	var box: StyleBoxFlat = style.box(Color.BLACK, Color.WHITE, 1, style.CORNER, true)
	print("a battle panel has straight-cut corners, no smoothing and no soft shadow: detail=%d aa=%s shadow=%d (expected 1, false, 0)" % [box.corner_detail, box.anti_aliasing, box.shadow_size])
	var chamfered: StyleBoxFlat = style.chamfer(StyleBoxFlat.new(), 4)
	print("chamfer() does the same to any box: radius=%d detail=%d aa=%s (expected 4, 1, false)" % [chamfered.corner_radius_top_left, chamfered.corner_detail, chamfered.anti_aliasing])

	# --- the type ---
	var theme_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	print("the project's default theme is the pixel theme: '%s' (expected res://assets/ui/pixel_theme.tres)" % theme_path)
	var theme: Theme = load(theme_path) if theme_path != "" else null
	var default_font: Font = theme.default_font if theme != null else null
	print("...whose font is Jersey 10 at 20px: %s, size %d (expected the Jersey10 file, 20)" % [default_font.resource_path.get_file() if default_font != null else "none", theme.default_font_size if theme != null else -1])
	var smoothing_off := true
	for kind in ["body", "head", "myth"]:
		var f: FontFile = kit.font(kind)
		if f.antialiasing != TextServer.FONT_ANTIALIASING_NONE or f.hinting != TextServer.HINTING_NONE or f.subpixel_positioning != TextServer.SUBPIXEL_POSITIONING_DISABLED:
			smoothing_off = false
	print("all three pixel fonts are drawn with no smoothing, hinting or half-pixel placement: %s (expected true)" % smoothing_off)
	var label := Label.new()
	var sizes: Array = []
	for px in [9, 11, 12, 13, 16, 20, 23, 24, 30]:
		kit.fit(label, px)
		sizes.append("%d->%d" % [px, label.get_theme_font_size("font_size")])
	print("old sizes land on the font's grid: %s (expected 9->10 11->15 12->15 13->20 16->20 20->20 23->20 24->30 30->30)" % [" ".join(sizes)])
	kit.fit(label, 16)
	var body_font: bool = label.get_theme_font("font").resource_path.get_file().begins_with("Jersey10")
	kit.fit(label, 12)
	var head_font: bool = label.get_theme_font("font").resource_path.get_file().begins_with("Jersey15")
	print("...and the font switches with them: 16px is Jersey 10 (%s), 12px is Jersey 15 (%s) (expected true, true)" % [body_font, head_font])
	label.free()

	# --- the Berserk vignette ---
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var hud = main.hud
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var orc = load("res://scripts/Orc.gd").new()
	main.add_child(orc)
	orc.global_position = main.player.global_position + Vector2(30, 0)
	main.trigger_battle(orc)
	await process_frame
	await process_frame
	main.player.berserk_turns_remaining = 0
	main._refresh_battle_display()
	print("no Berserk, no vignette: visible=%s (expected false)" % hud.battle_berserk_vignette.visible)
	main.player.berserk_turns_remaining = 2
	main._refresh_battle_display()
	print("Berserk shows the red vignette: visible=%s (expected true), texture filter nearest=%s (expected true), covers the screen: %s (expected true), ignores the mouse: %s (expected true)" % [
		hud.battle_berserk_vignette.visible, hud.battle_berserk_vignette.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		hud.battle_berserk_vignette.size.is_equal_approx(hud.battle_panel.size) or hud.battle_berserk_vignette.anchor_right == 1.0, hud.battle_berserk_vignette.mouse_filter == Control.MOUSE_FILTER_IGNORE])
	var red_img: Image = hud.battle_berserk_vignette.texture.get_image()
	var corner: Color = red_img.get_pixel(0, 0)
	print("...and it is red and stepped: corner r=%.2f g=%.2f b=%.2f a=%.2f (expected a red with alpha about 0.55)" % [corner.r, corner.g, corner.b, corner.a])
	main.player.berserk_turns_remaining = 0
	main._refresh_battle_display()
	print("it goes away when Berserk does: visible=%s (expected false)" % hud.battle_berserk_vignette.visible)
	main.player.berserk_turns_remaining = 2
	main._refresh_battle_display()
	hud.hide_battle()
	print("...and when the battle is hidden: visible=%s (expected false)" % hud.battle_berserk_vignette.visible)
	var bg: Image = hud.battle_gradient_rect.texture.get_image()
	print("the battle backdrop is banded, not blended: %d bands (expected 9), nearest filter=%s (expected true)" % [bg.get_height(), hud.battle_gradient_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST])
	quit()

func _distinct(img: Image) -> int:
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			seen[img.get_pixel(x, y).to_rgba32()] = true
	return seen.size()
