extends SceneTree

# Writes assets/ui/pixel_theme.tres, the project's default theme (Project Settings > GUI > Theme > Custom): the pixel font Jersey 10 at its native
# 2x size, so every label, button and text box that does not pick a font of its own is set in pixel type instead of the engine's smooth default.
# The older screens ask for sizes in arbitrary pixels; PixelKit.fit() puts those on the fonts' grids.
#
#   godot --headless --path . --script res://tools/gen_pixel_theme.gd

func _init() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/Jersey10-Regular.ttf")
	theme.default_font_size = 20
	var err := ResourceSaver.save(theme, "res://assets/ui/pixel_theme.tres")
	print("pixel_theme.tres saved: %s" % ("ok" if err == OK else "error %d" % err))
	quit()
