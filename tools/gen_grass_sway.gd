extends SceneTree

# Two extra frames derived from the hand-drawn GrassTile.png, each a whole-
# tile horizontal wraparound shift -- a modular shift of a periodic (tileable)
# image is still perfectly periodic, so these stay seamless with
# TextureRect's STRETCH_TILE the same as frame 0. Frame order (0, +1, -1) reads
# as a gentle side-to-side sway when looped, rather than a one-directional
# scroll like the water current's animation.
func make_shifted_frame(base: Image, shift: int) -> Image:
	var w := base.get_width()
	var h := base.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var src_x := ((x - shift) % w + w) % w
		for y in h:
			img.set_pixel(x, y, base.get_pixel(src_x, y))
	return img

func _init() -> void:
	var base := Image.load_from_file("res://Sprites/GrassTile.png")
	make_shifted_frame(base, 1).save_png("res://Sprites/GrassTile_1.png")
	make_shifted_frame(base, -1).save_png("res://Sprites/GrassTile_2.png")
	print("grass sway frames generated")
	quit()
