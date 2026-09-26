extends SceneTree

func fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			img.set_pixel(x, y, color)

func set_px(img: Image, x: int, y: int, color: Color) -> void:
	img.set_pixel(x, y, color)

# Staircased diagonal bar (bottom-left to top-right), matching the blocky
# pixel-art look of a weapon handle/blade seen at an angle. Thickness expands
# toward +x/-y (inward, away from the starting corner) to stay in bounds.
func draw_diag(img: Image, x0: int, y0: int, steps: int, thickness: int, color: Color) -> void:
	for i in steps:
		var x := x0 + i
		var y := y0 - i
		fill_rect(img, x, y - (thickness - 1), x + thickness - 1, y, color)

func make_barbarian() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.11, 0.09, 0.07, 1.0)
	var H := Color(0.2, 0.13, 0.08, 1.0)
	var S := Color(0.85, 0.63, 0.42, 1.0)
	var D := Color(0.68, 0.48, 0.3, 1.0)
	var F := Color(0.55, 0.35, 0.15, 1.0)
	var B := Color(0.3, 0.19, 0.1, 1.0)
	var W := Color(0.78, 0.78, 0.8, 1.0)
	var M := Color(0.4, 0.26, 0.13, 1.0)
	var R := Color(0.7, 0.15, 0.15, 1.0)

	fill_rect(img, 4, 0, 11, 7, K)
	fill_rect(img, 3, 6, 12, 12, K)
	fill_rect(img, 1, 7, 4, 11, K)
	fill_rect(img, 11, 7, 14, 11, K)
	fill_rect(img, 3, 11, 12, 15, K)

	fill_rect(img, 6, 0, 9, 1, H)
	fill_rect(img, 4, 1, 11, 2, H)

	fill_rect(img, 5, 2, 10, 6, S)
	set_px(img, 6, 4, K)
	set_px(img, 9, 4, K)
	fill_rect(img, 6, 6, 9, 6, D)

	fill_rect(img, 4, 7, 11, 10, S)
	fill_rect(img, 4, 9, 11, 9, D)
	fill_rect(img, 4, 11, 11, 11, B)
	set_px(img, 4, 7, R)
	set_px(img, 11, 7, R)

	fill_rect(img, 3, 12, 12, 13, F)

	fill_rect(img, 5, 14, 7, 14, S)
	fill_rect(img, 9, 14, 11, 14, S)
	fill_rect(img, 5, 15, 7, 15, B)
	fill_rect(img, 9, 15, 11, 15, B)

	fill_rect(img, 2, 8, 3, 10, S)
	fill_rect(img, 12, 8, 13, 10, S)

	fill_rect(img, 13, 3, 14, 9, M)
	fill_rect(img, 12, 1, 15, 4, W)

	return img

# Blade Ally: the Warrior-branch skill tree companion. Reuses the
# barbarian's overall silhouette proportions (same humanoid shape reads
# instantly as "a person", not a monster) but in a cool hooded-rogue palette
# instead of the player's warm tan/brown, so it's unmistakably a second,
# distinct character standing next to the player rather than a recolor.
func make_blade_ally() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.06, 0.08, 0.1, 1.0)
	var HOOD := Color(0.15, 0.32, 0.4, 1.0)
	var HOOD_L := Color(0.22, 0.45, 0.52, 1.0)
	var SK := Color(0.85, 0.68, 0.55, 1.0)
	var CL := Color(0.18, 0.4, 0.48, 1.0)
	var CL_D := Color(0.12, 0.28, 0.34, 1.0)
	var BT := Color(0.16, 0.14, 0.13, 1.0)
	var BL := Color(0.78, 0.82, 0.86, 1.0)
	var HN := Color(0.32, 0.23, 0.16, 1.0)

	fill_rect(img, 4, 1, 11, 7, K)
	fill_rect(img, 3, 6, 12, 12, K)
	fill_rect(img, 1, 7, 4, 11, K)
	fill_rect(img, 11, 7, 14, 11, K)
	fill_rect(img, 3, 11, 12, 15, K)

	fill_rect(img, 5, 1, 10, 3, HOOD)
	fill_rect(img, 4, 3, 11, 5, HOOD)
	fill_rect(img, 5, 2, 8, 2, HOOD_L)
	fill_rect(img, 6, 4, 9, 6, SK)
	set_px(img, 7, 5, K)
	set_px(img, 8, 5, K)

	fill_rect(img, 4, 7, 11, 10, CL)
	fill_rect(img, 4, 9, 11, 9, CL_D)
	fill_rect(img, 4, 11, 11, 11, CL_D)

	fill_rect(img, 2, 8, 3, 10, CL)
	fill_rect(img, 12, 8, 13, 10, CL)

	fill_rect(img, 3, 12, 12, 13, CL_D)
	fill_rect(img, 5, 14, 7, 15, BT)
	fill_rect(img, 9, 14, 11, 15, BT)

	fill_rect(img, 13, 4, 14, 10, BL)
	fill_rect(img, 12, 9, 15, 10, HN)

	return img

func make_goblin() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.15, 0.06, 1.0)
	var G := Color(0.44, 0.68, 0.3, 1.0)
	var Gd := Color(0.32, 0.5, 0.22, 1.0)
	var E := Color(1.0, 1.0, 1.0, 1.0)
	var F := Color(0.5, 0.32, 0.14, 1.0)
	var W := Color(0.8, 0.8, 0.82, 1.0)

	fill_rect(img, 3, 2, 12, 14, K)

	fill_rect(img, 4, 3, 11, 13, G)
	fill_rect(img, 4, 10, 11, 11, Gd)

	fill_rect(img, 2, 4, 3, 6, G)
	fill_rect(img, 12, 4, 13, 6, G)

	fill_rect(img, 5, 5, 6, 6, E)
	fill_rect(img, 9, 5, 10, 6, E)
	set_px(img, 6, 6, K)
	set_px(img, 9, 6, K)

	set_px(img, 6, 8, E)
	set_px(img, 9, 8, E)

	fill_rect(img, 5, 11, 10, 12, F)

	fill_rect(img, 5, 13, 7, 14, G)
	fill_rect(img, 8, 13, 10, 14, G)
	fill_rect(img, 5, 15, 7, 15, K)
	fill_rect(img, 8, 15, 10, 15, K)

	fill_rect(img, 3, 8, 4, 10, G)
	fill_rect(img, 11, 8, 12, 10, G)
	fill_rect(img, 12, 7, 13, 9, W)

	return img

func make_orc() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.09, 0.08, 0.07, 1.0)
	var O := Color(0.45, 0.42, 0.32, 1.0)
	var Od := Color(0.33, 0.3, 0.22, 1.0)
	var T := Color(0.92, 0.9, 0.82, 1.0)
	var E := Color(0.85, 0.15, 0.1, 1.0)
	var F := Color(0.22, 0.17, 0.13, 1.0)
	var W := Color(0.35, 0.22, 0.1, 1.0)
	var Wh := Color(0.5, 0.5, 0.52, 1.0)

	fill_rect(img, 2, 0, 13, 15, K)

	fill_rect(img, 5, 1, 10, 5, O)
	set_px(img, 6, 3, E)
	set_px(img, 9, 3, E)
	set_px(img, 6, 5, T)
	set_px(img, 9, 5, T)

	fill_rect(img, 3, 6, 12, 12, O)
	fill_rect(img, 3, 10, 12, 11, Od)
	fill_rect(img, 3, 12, 12, 12, F)

	fill_rect(img, 4, 13, 7, 15, O)
	fill_rect(img, 8, 13, 11, 15, O)
	fill_rect(img, 4, 15, 7, 15, K)
	fill_rect(img, 8, 15, 11, 15, K)

	fill_rect(img, 1, 7, 2, 10, O)
	fill_rect(img, 12, 7, 13, 10, O)

	fill_rect(img, 13, 8, 14, 13, W)
	fill_rect(img, 12, 5, 15, 8, Wh)

	return img

func make_archer() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.12, 0.08, 1.0)
	var C := Color(0.3, 0.42, 0.24, 1.0)
	var Cd := Color(0.22, 0.32, 0.17, 1.0)
	var S := Color(0.75, 0.6, 0.45, 1.0)
	var E := Color(1.0, 1.0, 1.0, 1.0)
	var Bow := Color(0.45, 0.3, 0.15, 1.0)

	fill_rect(img, 5, 1, 10, 6, K)
	fill_rect(img, 6, 2, 9, 5, S)
	set_px(img, 7, 3, E)
	set_px(img, 8, 3, E)

	fill_rect(img, 4, 6, 11, 13, K)
	fill_rect(img, 5, 7, 10, 12, C)
	fill_rect(img, 5, 10, 10, 11, Cd)

	fill_rect(img, 5, 13, 7, 15, K)
	fill_rect(img, 8, 13, 10, 15, K)

	fill_rect(img, 3, 8, 4, 11, C)
	fill_rect(img, 11, 8, 12, 11, C)

	# Bow silhouette held out to one side -- the tell that this one hits
	# from range instead of closing in like everything else.
	for i in 10:
		set_px(img, 13, 2 + i, Bow)
	set_px(img, 12, 3, Bow)
	set_px(img, 14, 3, Bow)
	set_px(img, 12, 10, Bow)
	set_px(img, 14, 10, Bow)

	return img

func make_shaman() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.08, 0.14, 1.0)
	var R := Color(0.3, 0.22, 0.5, 1.0)
	var Rd := Color(0.22, 0.16, 0.38, 1.0)
	var S := Color(0.55, 0.6, 0.4, 1.0)
	var E := Color(0.9, 0.85, 0.2, 1.0)
	var Staff := Color(0.4, 0.28, 0.14, 1.0)
	var Orb := Color(0.5, 0.85, 0.9, 1.0)

	fill_rect(img, 5, 0, 10, 5, K)
	fill_rect(img, 6, 1, 9, 4, S)
	set_px(img, 7, 2, E)
	set_px(img, 8, 2, E)

	# Long flowing robe instead of a fitted tunic.
	fill_rect(img, 3, 5, 12, 15, K)
	fill_rect(img, 4, 6, 11, 14, R)
	fill_rect(img, 4, 10, 11, 11, Rd)
	fill_rect(img, 4, 13, 11, 14, Rd)

	fill_rect(img, 2, 7, 3, 10, R)

	# Staff topped with a glowing orb -- the healer's signature prop.
	fill_rect(img, 12, 4, 13, 14, Staff)
	fill_rect(img, 11, 2, 14, 4, Orb)

	return img

func make_brute() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.09, 0.08, 1.0)
	var Bd := Color(0.4, 0.36, 0.32, 1.0)
	var Bdd := Color(0.3, 0.27, 0.23, 1.0)
	var T := Color(0.9, 0.88, 0.8, 1.0)
	var E := Color(0.7, 0.1, 0.1, 1.0)
	var F := Color(0.18, 0.15, 0.12, 1.0)
	var Ch := Color(0.5, 0.48, 0.45, 1.0)

	# Wider, squatter silhouette than the Orc -- pure bulk.
	fill_rect(img, 3, 1, 12, 6, Bd)
	set_px(img, 5, 3, E)
	set_px(img, 10, 3, E)
	set_px(img, 5, 5, T)
	set_px(img, 6, 5, T)
	set_px(img, 9, 5, T)
	set_px(img, 10, 5, T)

	fill_rect(img, 1, 6, 14, 13, Bd)
	fill_rect(img, 1, 10, 14, 11, Bdd)
	fill_rect(img, 1, 13, 14, 13, F)

	fill_rect(img, 3, 14, 6, 15, Bd)
	fill_rect(img, 9, 14, 12, 15, Bd)
	fill_rect(img, 3, 15, 6, 15, K)
	fill_rect(img, 9, 15, 12, 15, K)

	fill_rect(img, 0, 7, 1, 12, Bd)
	fill_rect(img, 14, 7, 15, 12, Bd)

	# A chain draped across the chest -- reads as heavy, armored bulk that
	# just walks through whatever you're hiding behind.
	for i in 6:
		set_px(img, 4 + i, 9 + (i % 2), Ch)

	return img

func make_shade() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.03, 0.02, 0.05, 1.0)
	var P := Color(0.2, 0.12, 0.28, 1.0)
	var Pd := Color(0.14, 0.08, 0.2, 1.0)
	var E := Color(0.85, 0.15, 0.75, 1.0)

	fill_rect(img, 5, 1, 10, 5, K)
	fill_rect(img, 6, 2, 9, 4, P)
	set_px(img, 7, 3, E)
	set_px(img, 8, 3, E)

	fill_rect(img, 4, 5, 11, 12, K)
	fill_rect(img, 5, 6, 10, 11, P)
	fill_rect(img, 5, 9, 10, 10, Pd)

	# Tattered, jagged cloak hem instead of a flat bottom edge -- reads as
	# fast and insubstantial next to the other enemies' solid blocks.
	fill_rect(img, 5, 13, 5, 14, K)
	fill_rect(img, 7, 13, 8, 15, K)
	fill_rect(img, 10, 13, 10, 14, K)

	fill_rect(img, 2, 6, 3, 10, P)
	fill_rect(img, 12, 6, 13, 10, P)

	return img

func make_wolf() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.15, 0.17, 1.0)
	var F := Color(0.45, 0.45, 0.48, 1.0)
	var Fd := Color(0.32, 0.32, 0.35, 1.0)
	var S := Color(0.82, 0.8, 0.75, 1.0)
	var E := Color(0.95, 0.85, 0.2, 1.0)
	var N := Color(0.05, 0.05, 0.05, 1.0)

	# Pointed ears
	fill_rect(img, 3, 0, 5, 2, K)
	fill_rect(img, 10, 0, 12, 2, K)
	set_px(img, 4, 1, F)
	set_px(img, 11, 1, F)

	# Head, tapering to a snout
	fill_rect(img, 3, 2, 12, 7, K)
	fill_rect(img, 4, 3, 11, 6, F)
	set_px(img, 6, 4, E)
	set_px(img, 9, 4, E)
	fill_rect(img, 6, 6, 9, 7, S)
	set_px(img, 7, 7, N)
	set_px(img, 8, 7, N)

	# Body
	fill_rect(img, 3, 7, 12, 13, K)
	fill_rect(img, 4, 8, 11, 12, F)
	fill_rect(img, 4, 11, 11, 12, Fd)
	fill_rect(img, 5, 9, 10, 10, S)

	# Legs
	fill_rect(img, 4, 13, 6, 15, K)
	fill_rect(img, 9, 13, 11, 15, K)
	fill_rect(img, 4, 14, 5, 15, F)
	fill_rect(img, 9, 14, 10, 15, F)

	# Tail
	fill_rect(img, 12, 9, 14, 12, K)
	fill_rect(img, 12, 10, 13, 11, F)

	return img

func make_coin() -> Image:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.45, 0.32, 0.05, 1.0)
	var G := Color(0.95, 0.78, 0.2, 1.0)
	var Gd := Color(0.78, 0.6, 0.1, 1.0)
	var Hl := Color(1.0, 0.95, 0.7, 1.0)

	fill_rect(img, 2, 1, 9, 10, K)
	fill_rect(img, 3, 2, 8, 9, G)
	fill_rect(img, 3, 6, 8, 7, Gd)
	set_px(img, 4, 3, Hl)
	set_px(img, 5, 3, Hl)

	return img

func make_meat() -> Image:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.25, 0.14, 0.09, 1.0)
	var M := Color(0.72, 0.32, 0.28, 1.0)
	var Md := Color(0.55, 0.22, 0.2, 1.0)
	var Bn := Color(0.92, 0.88, 0.8, 1.0)

	fill_rect(img, 1, 1, 8, 8, K)
	fill_rect(img, 2, 2, 7, 7, M)
	fill_rect(img, 2, 5, 7, 7, Md)
	fill_rect(img, 7, 7, 10, 10, K)
	fill_rect(img, 8, 8, 9, 9, Bn)

	return img

func make_icon_club() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.09, 0.05, 1.0)
	var H := Color(0.42, 0.27, 0.14, 1.0)
	var W := Color(0.55, 0.38, 0.2, 1.0)
	var Wd := Color(0.42, 0.28, 0.14, 1.0)

	draw_diag(img, 2, 17, 9, 4, K)
	draw_diag(img, 3, 16, 8, 2, H)

	fill_rect(img, 9, 1, 17, 9, K)
	fill_rect(img, 10, 2, 16, 8, W)
	fill_rect(img, 10, 5, 16, 8, Wd)

	return img

func make_runic_shard() -> Image:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.08, 0.25, 1.0)
	var P := Color(0.55, 0.35, 0.85, 1.0)
	var Pd := Color(0.38, 0.22, 0.65, 1.0)
	var Hl := Color(0.85, 0.75, 1.0, 1.0)

	# An angular crystal shard -- pointed top and bottom, distinct from the
	# coin's round silhouette and the meat's blocky one.
	fill_rect(img, 4, 0, 7, 1, K)
	fill_rect(img, 2, 1, 9, 3, K)
	fill_rect(img, 1, 3, 10, 8, K)
	fill_rect(img, 2, 8, 9, 10, K)
	fill_rect(img, 4, 10, 7, 11, K)

	fill_rect(img, 3, 2, 8, 3, P)
	fill_rect(img, 2, 3, 9, 7, P)
	fill_rect(img, 3, 7, 8, 9, Pd)
	fill_rect(img, 5, 9, 6, 9, Pd)
	set_px(img, 4, 3, Hl)
	set_px(img, 5, 3, Hl)

	return img

func make_icon_spear() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.14, 0.09, 0.05, 1.0)
	var H := Color(0.45, 0.3, 0.16, 1.0)
	var Tp := Color(0.65, 0.65, 0.68, 1.0)
	var Tpl := Color(0.85, 0.85, 0.88, 1.0)

	draw_diag(img, 1, 18, 13, 3, K)
	draw_diag(img, 2, 17, 12, 1, H)

	# Tapering triangular spearhead (each band narrower and higher than the
	# last) instead of a flat square, so it reads as a point, not a gem.
	fill_rect(img, 11, 7, 15, 9, K)
	fill_rect(img, 12, 7, 14, 8, Tp)
	fill_rect(img, 13, 5, 16, 7, K)
	fill_rect(img, 14, 5, 15, 6, Tp)
	fill_rect(img, 15, 3, 17, 5, K)
	fill_rect(img, 16, 3, 16, 4, Tp)
	fill_rect(img, 17, 1, 18, 3, K)
	set_px(img, 17, 2, Tpl)

	return img

func make_icon_greatsword() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.12, 0.1, 0.09, 1.0)
	var H := Color(0.4, 0.26, 0.13, 1.0)
	var Bl := Color(0.68, 0.68, 0.72, 1.0)
	var Bd := Color(0.5, 0.5, 0.54, 1.0)

	draw_diag(img, 2, 17, 4, 3, K)
	draw_diag(img, 3, 16, 3, 1, H)

	draw_diag(img, 5, 14, 11, 5, K)
	draw_diag(img, 6, 13, 10, 3, Bl)
	draw_diag(img, 6, 13, 10, 1, Bd)

	return img

func make_icon_hammer() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.05, 0.06, 1.0)
	var H := Color(0.2, 0.2, 0.22, 1.0)
	var He := Color(0.28, 0.28, 0.3, 1.0)
	var Hed := Color(0.4, 0.4, 0.43, 1.0)

	draw_diag(img, 2, 17, 8, 3, K)
	draw_diag(img, 3, 16, 7, 1, H)

	fill_rect(img, 9, 2, 17, 10, K)
	fill_rect(img, 10, 3, 16, 9, He)
	fill_rect(img, 10, 3, 13, 6, Hed)

	return img

func make_icon_battle_axe() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.13, 0.09, 0.05, 1.0)
	var H := Color(0.42, 0.27, 0.14, 1.0)
	var Bl := Color(0.62, 0.62, 0.66, 1.0)
	var Bd := Color(0.46, 0.46, 0.5, 1.0)

	draw_diag(img, 1, 18, 10, 3, K)
	draw_diag(img, 2, 17, 9, 1, H)

	# Asymmetric wedge blade (base near the handle, flaring wider toward the
	# top) instead of a uniform block, so the silhouette reads as an axe
	# rather than a hammer's plain square head.
	fill_rect(img, 9, 5, 13, 11, K)
	fill_rect(img, 10, 6, 12, 10, Bl)

	fill_rect(img, 11, 0, 19, 8, K)
	fill_rect(img, 12, 1, 18, 7, Bl)
	fill_rect(img, 12, 1, 15, 4, Bd)

	return img

func make_icon_dagger() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.12, 0.09, 0.06, 1.0)
	var H := Color(0.35, 0.22, 0.12, 1.0)
	var Bl := Color(0.75, 0.76, 0.8, 1.0)
	var Bd := Color(0.55, 0.56, 0.6, 1.0)

	draw_diag(img, 3, 16, 5, 3, K)
	draw_diag(img, 4, 15, 4, 1, H)

	# Short, narrow blade -- reads as quick and light next to the longer
	# weapons.
	draw_diag(img, 7, 12, 7, 4, K)
	draw_diag(img, 8, 11, 6, 2, Bl)
	draw_diag(img, 8, 11, 6, 1, Bd)

	return img

func make_icon_bow() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.1, 0.05, 1.0)
	var W := Color(0.5, 0.34, 0.16, 1.0)
	var Str := Color(0.85, 0.82, 0.7, 1.0)

	# Curved wooden limbs approximated as a stepped arc, distinct from every
	# other weapon's straight-handle silhouette.
	fill_rect(img, 14, 1, 15, 3, K)
	fill_rect(img, 12, 3, 14, 4, K)
	fill_rect(img, 10, 5, 12, 6, K)
	fill_rect(img, 9, 7, 11, 12, K)
	fill_rect(img, 10, 13, 12, 14, K)
	fill_rect(img, 12, 15, 14, 16, K)
	fill_rect(img, 14, 16, 15, 18, K)

	fill_rect(img, 13, 2, 14, 3, W)
	fill_rect(img, 11, 4, 13, 4, W)
	fill_rect(img, 10, 6, 11, 6, W)
	fill_rect(img, 10, 7, 10, 12, W)
	fill_rect(img, 11, 13, 12, 13, W)
	fill_rect(img, 13, 15, 13, 15, W)

	# Taut string running straight down the open side.
	for i in 16:
		set_px(img, 15, 2 + i, Str)

	return img

# HUD-only icon (overworld quiver hover tooltip, HUD.gd) rather than a
# shop/weapon icon -- a tapered leather cylinder with three arrow shafts
# poking out the top, each fletched a different color so Flame/Freeze/Bomb
# read at a glance before the player even hovers for the exact counts.
func make_icon_quiver() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.1, 0.05, 1.0)
	var W := Color(0.5, 0.34, 0.16, 1.0)
	var Str := Color(0.85, 0.82, 0.7, 1.0)
	var FLAME := Color(0.9, 0.3, 0.15, 1.0)
	var FREEZE := Color(0.4, 0.7, 0.95, 1.0)
	var BOMB := Color(0.3, 0.3, 0.33, 1.0)

	# Leather quiver body: tapered cylinder, narrower opening at top.
	fill_rect(img, 4, 8, 11, 9, K)
	fill_rect(img, 3, 10, 12, 13, W)
	fill_rect(img, 4, 14, 11, 14, W)
	fill_rect(img, 5, 15, 10, 15, K)
	fill_rect(img, 3, 10, 3, 13, K)
	fill_rect(img, 12, 10, 12, 13, K)

	# Three arrow shafts poking out the top.
	fill_rect(img, 4, 2, 4, 9, Str)
	fill_rect(img, 4, 0, 4, 2, FLAME)
	fill_rect(img, 7, 1, 7, 9, Str)
	fill_rect(img, 7, 0, 7, 1, FREEZE)
	fill_rect(img, 10, 3, 10, 9, Str)
	fill_rect(img, 10, 1, 10, 3, BOMB)

	return img

# Settings screen's Screen Shake / Damage Numbers toggles -- a themed
# pixel-art switch (dark track/grey knob when off, bronze track/yellow knob
# when on) instead of Godot's stock CheckButton graphic, which reads as a
# completely different, unrelated UI kit next to everything else here.
func make_toggle_off() -> Image:
	var img := Image.create(28, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	fill_rect(img, 0, 0, 27, 13, Color(0.45, 0.42, 0.35, 0.9))
	fill_rect(img, 1, 1, 26, 12, Color(0.13, 0.12, 0.15, 0.95))
	fill_rect(img, 2, 2, 11, 11, Color(0.4, 0.4, 0.43, 1.0))
	return img

func make_toggle_on() -> Image:
	var img := Image.create(28, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	fill_rect(img, 0, 0, 27, 13, Color(0.62, 0.48, 0.2, 1.0))
	fill_rect(img, 1, 1, 26, 12, Color(0.28, 0.22, 0.09, 0.95))
	fill_rect(img, 16, 2, 25, 11, Color(1.0, 0.9, 0.2, 1.0))
	return img

func make_icon_knuckle_gloves() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.12, 0.1, 0.09, 1.0)
	var M := Color(0.55, 0.56, 0.6, 1.0)
	var Mh := Color(0.75, 0.76, 0.8, 1.0)
	var W := Color(0.35, 0.22, 0.12, 1.0)

	# Four knuckle bumps across the top -- the silhouette that reads as
	# "brawler" at a glance next to every bladed/hafted weapon in the roster.
	fill_rect(img, 2, 2, 17, 8, K)
	fill_rect(img, 3, 3, 6, 7, M)
	fill_rect(img, 8, 3, 11, 7, M)
	fill_rect(img, 13, 3, 16, 7, M)
	fill_rect(img, 3, 3, 4, 4, Mh)
	fill_rect(img, 8, 3, 9, 4, Mh)
	fill_rect(img, 13, 3, 14, 4, Mh)

	# Wrapped grip bar beneath.
	fill_rect(img, 3, 9, 16, 13, K)
	fill_rect(img, 4, 10, 15, 12, W)

	return img

func make_icon_hand_picks() -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.13, 0.09, 0.05, 1.0)
	var H := Color(0.42, 0.27, 0.14, 1.0)
	var Pk := Color(0.5, 0.5, 0.54, 1.0)
	var Pkd := Color(0.36, 0.36, 0.4, 1.0)

	draw_diag(img, 3, 17, 10, 3, K)
	draw_diag(img, 4, 16, 9, 1, H)

	# Double-headed pick, both ends tapering to points -- distinct from every
	# other weapon's single-blade or single-head silhouette.
	fill_rect(img, 11, 8, 18, 10, K)
	fill_rect(img, 12, 8, 17, 9, Pk)
	fill_rect(img, 1, 4, 8, 6, K)
	fill_rect(img, 2, 4, 7, 5, Pk)
	set_px(img, 18, 9, Pkd)
	set_px(img, 1, 5, Pkd)

	return img

func make_icon_potion() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.12, 0.08, 0.06, 1.0)
	var Cork := Color(0.45, 0.3, 0.16, 1.0)
	var Glass := Color(0.75, 0.85, 0.85, 0.6)
	var Liquid := Color(0.85, 0.15, 0.15, 1.0)
	var Shine := Color(1.0, 0.55, 0.55, 1.0)

	# Cork and neck.
	fill_rect(img, 6, 0, 9, 1, K)
	set_px(img, 7, 0, Cork)
	set_px(img, 8, 0, Cork)
	fill_rect(img, 6, 2, 9, 4, K)
	fill_rect(img, 7, 2, 8, 4, Glass)

	# Rounded bottle body.
	fill_rect(img, 3, 5, 12, 14, K)
	fill_rect(img, 4, 6, 11, 13, Liquid)
	set_px(img, 3, 5, Color(0, 0, 0, 0))
	set_px(img, 12, 5, Color(0, 0, 0, 0))
	set_px(img, 3, 14, Color(0, 0, 0, 0))
	set_px(img, 12, 14, Color(0, 0, 0, 0))

	fill_rect(img, 5, 7, 6, 10, Shine)

	return img

func make_icon_armor_rags() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.2, 0.16, 0.1, 1.0)
	var C := Color(0.55, 0.48, 0.35, 1.0)
	var Cd := Color(0.42, 0.36, 0.25, 1.0)

	fill_rect(img, 4, 2, 11, 13, K)
	fill_rect(img, 5, 3, 10, 12, C)
	fill_rect(img, 5, 8, 10, 12, Cd)

	# Ragged notches carved out of the silhouette.
	fill_rect(img, 4, 12, 5, 13, Color(0, 0, 0, 0))
	fill_rect(img, 10, 13, 11, 13, Color(0, 0, 0, 0))
	set_px(img, 6, 2, Color(0, 0, 0, 0))
	set_px(img, 9, 13, Color(0, 0, 0, 0))

	return img

func make_icon_armor_leather() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.16, 0.1, 0.05, 1.0)
	var L := Color(0.5, 0.32, 0.16, 1.0)
	var Ld := Color(0.38, 0.24, 0.12, 1.0)

	fill_rect(img, 4, 1, 11, 14, K)
	fill_rect(img, 5, 2, 10, 13, L)
	fill_rect(img, 5, 8, 10, 13, Ld)
	fill_rect(img, 7, 2, 8, 13, K)

	return img

func make_icon_armor_iron() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.1, 0.11, 1.0)
	var I := Color(0.58, 0.6, 0.64, 1.0)
	var Ihl := Color(0.78, 0.8, 0.84, 1.0)

	fill_rect(img, 3, 1, 12, 14, K)
	fill_rect(img, 4, 2, 11, 13, I)
	fill_rect(img, 4, 2, 7, 6, Ihl)
	set_px(img, 5, 8, K)
	set_px(img, 10, 8, K)
	fill_rect(img, 7, 8, 8, 11, K)

	return img

func make_icon_armor_steel() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.07, 0.08, 0.11, 1.0)
	var S := Color(0.42, 0.48, 0.58, 1.0)
	var Shl := Color(0.62, 0.7, 0.82, 1.0)

	fill_rect(img, 3, 1, 12, 14, K)
	fill_rect(img, 4, 2, 11, 13, S)
	fill_rect(img, 4, 2, 7, 6, Shl)
	set_px(img, 5, 8, K)
	set_px(img, 10, 8, K)
	fill_rect(img, 7, 8, 8, 11, K)
	# Extra banded plate seams -- a step up from Iron's single flat slab.
	fill_rect(img, 4, 5, 11, 5, K)
	fill_rect(img, 4, 10, 11, 10, K)

	return img

func make_icon_armor_dragonskin() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.1, 0.06, 1.0)
	var D := Color(0.18, 0.42, 0.22, 1.0)
	var Dd := Color(0.12, 0.3, 0.16, 1.0)
	var Hl := Color(0.35, 0.62, 0.32, 1.0)
	var Spine := Color(0.75, 0.2, 0.15, 1.0)

	fill_rect(img, 3, 1, 12, 14, K)
	fill_rect(img, 4, 2, 11, 13, D)
	fill_rect(img, 4, 2, 7, 6, Hl)
	fill_rect(img, 4, 9, 11, 13, Dd)

	# Staggered notches read as overlapping scales instead of one solid slab.
	for row in range(3, 12, 3):
		for col in range(4, 11, 2):
			set_px(img, col, row, Dd)

	# A ridge of small spine spikes down the centerline -- the dragon-sourced
	# tell that separates this from every other armor's flat silhouette.
	set_px(img, 7, 1, Spine)
	set_px(img, 8, 1, Spine)
	set_px(img, 7, 4, Spine)
	set_px(img, 8, 4, Spine)
	set_px(img, 7, 7, Spine)
	set_px(img, 8, 7, Spine)

	return img

# Rounded heater-shield silhouette (narrow at top and tapering to a point at
# the bottom), built from stepped bands -- distinct from armor's rectangular
# vest shape.
func draw_shield_shape(img: Image, color: Color) -> void:
	fill_rect(img, 6, 1, 9, 2, color)
	fill_rect(img, 5, 3, 10, 4, color)
	fill_rect(img, 4, 5, 11, 9, color)
	fill_rect(img, 5, 10, 10, 11, color)
	fill_rect(img, 6, 12, 9, 13, color)
	set_px(img, 7, 14, color)
	set_px(img, 8, 14, color)

func make_icon_shield_wood() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.2, 0.13, 0.06, 1.0)
	var W := Color(0.5, 0.34, 0.16, 1.0)
	var Wd := Color(0.38, 0.25, 0.11, 1.0)
	var B := Color(0.55, 0.55, 0.58, 1.0)

	draw_shield_shape(img, K)
	fill_rect(img, 5, 3, 10, 12, W)
	fill_rect(img, 4, 6, 11, 7, Wd)
	fill_rect(img, 4, 10, 11, 10, Wd)
	fill_rect(img, 6, 6, 9, 9, B)
	fill_rect(img, 7, 7, 8, 8, Wd)

	return img

func make_icon_shield_iron() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.1, 0.11, 1.0)
	var I := Color(0.6, 0.62, 0.66, 1.0)
	var Ihl := Color(0.8, 0.82, 0.86, 1.0)

	draw_shield_shape(img, K)
	fill_rect(img, 5, 3, 10, 12, I)
	fill_rect(img, 5, 3, 7, 5, Ihl)
	fill_rect(img, 6, 6, 9, 9, Ihl)
	fill_rect(img, 7, 7, 8, 8, K)

	return img

# Round Shield -- a bronze rim and central boss over deep red, the look of a
# spear-fighter's shield even on the same heater silhouette as the rest.
func make_icon_shield_round() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.25, 0.08, 0.05, 1.0)
	var R := Color(0.65, 0.18, 0.12, 1.0)
	var Rd := Color(0.5, 0.12, 0.08, 1.0)
	var B := Color(0.7, 0.62, 0.3, 1.0)

	draw_shield_shape(img, K)
	fill_rect(img, 5, 3, 10, 12, R)
	fill_rect(img, 4, 9, 11, 12, Rd)
	fill_rect(img, 5, 3, 10, 3, B)
	fill_rect(img, 6, 7, 9, 8, B)

	return img

# Phantom Guard -- pale, half-translucent blue, barely more than a bracer.
func make_icon_shield_phantom() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.18, 0.25, 0.7)
	var P := Color(0.55, 0.68, 0.85, 0.55)
	var Pd := Color(0.4, 0.52, 0.7, 0.5)
	var Hl := Color(0.85, 0.92, 1.0, 0.7)

	draw_shield_shape(img, K)
	fill_rect(img, 5, 3, 10, 12, P)
	fill_rect(img, 4, 9, 11, 12, Pd)
	fill_rect(img, 5, 3, 8, 5, Hl)

	return img

# Brawler's Buckler -- dark leather with aggressive red rivets, strapped for
# the forearm rather than carried by a grip.
func make_icon_shield_brawler() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.14, 0.09, 0.06, 1.0)
	var Lthr := Color(0.42, 0.26, 0.14, 1.0)
	var Lthrd := Color(0.3, 0.18, 0.09, 1.0)
	var Riv := Color(0.6, 0.15, 0.1, 1.0)

	draw_shield_shape(img, K)
	fill_rect(img, 5, 3, 10, 12, Lthr)
	fill_rect(img, 4, 9, 11, 12, Lthrd)
	set_px(img, 6, 5, Riv)
	set_px(img, 9, 5, Riv)
	set_px(img, 6, 10, Riv)
	set_px(img, 9, 10, Riv)

	return img

# ---------------------------------------------------------------------
# Reserved terrain (Main.gd:RESERVED_TERRAIN_TYPES) -- full-bleed ground
# tiles like Rock/Cliff/Ledge, not padded icons like the weapon/shield set
# above. Not rolled by any real battle yet (see that const's doc comment),
# but rendered correctly the moment one is.
# ---------------------------------------------------------------------

func make_icon_terrain_ice() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color(0.72, 0.87, 0.95, 1.0)
	var crack := Color(0.88, 0.96, 1.0, 1.0)
	var deep := Color(0.55, 0.75, 0.88, 1.0)
	img.fill(base)
	fill_rect(img, 0, 10, 15, 15, deep)
	draw_diag(img, 2, 6, 6, 1, crack)
	draw_diag(img, 9, 13, 5, 1, crack)
	set_px(img, 4, 3, crack)
	set_px(img, 12, 4, crack)
	return img

func make_icon_terrain_embers() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ash := Color(0.16, 0.12, 0.1, 1.0)
	var ash_dk := Color(0.1, 0.07, 0.06, 1.0)
	var glow := Color(0.95, 0.45, 0.1, 1.0)
	var glow_hot := Color(1.0, 0.75, 0.2, 1.0)
	img.fill(ash)
	fill_rect(img, 0, 9, 15, 15, ash_dk)
	fill_rect(img, 3, 4, 5, 6, glow)
	fill_rect(img, 9, 7, 11, 9, glow)
	fill_rect(img, 6, 11, 8, 13, glow)
	set_px(img, 4, 5, glow_hot)
	set_px(img, 10, 8, glow_hot)
	set_px(img, 7, 12, glow_hot)
	return img

func make_icon_terrain_poison_bog() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var muck := Color(0.28, 0.32, 0.14, 1.0)
	var muck_dk := Color(0.19, 0.22, 0.09, 1.0)
	var bubble := Color(0.55, 0.75, 0.2, 1.0)
	img.fill(muck)
	fill_rect(img, 0, 10, 15, 15, muck_dk)
	set_px(img, 4, 4, bubble)
	set_px(img, 5, 5, bubble)
	set_px(img, 11, 6, bubble)
	set_px(img, 8, 9, bubble)
	set_px(img, 12, 11, bubble)
	return img

func make_icon_terrain_quicksand() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var sand := Color(0.76, 0.66, 0.42, 1.0)
	var sand_dk := Color(0.64, 0.54, 0.32, 1.0)
	img.fill(sand)
	for x0 in [1, 5, 9]:
		draw_diag(img, x0, 3, 2, 1, sand_dk)
		draw_diag(img, x0 + 1, 12, 2, 1, sand_dk)
	return img

func make_icon_terrain_spring() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var bank := Color(0.36, 0.55, 0.32, 1.0)
	var pool := Color(0.4, 0.75, 0.85, 1.0)
	var sparkle := Color(0.9, 1.0, 0.98, 1.0)
	img.fill(bank)
	fill_rect(img, 3, 3, 12, 12, pool)
	set_px(img, 6, 5, sparkle)
	set_px(img, 9, 8, sparkle)
	set_px(img, 5, 9, sparkle)
	return img

func make_icon_terrain_crumbling() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var stone := Color(0.48, 0.47, 0.46, 1.0)
	var crack := Color(0.28, 0.27, 0.26, 1.0)
	img.fill(stone)
	draw_diag(img, 2, 4, 5, 1, crack)
	draw_diag(img, 7, 14, 4, 1, crack)
	draw_diag(img, 10, 3, 4, 1, crack)
	return img

func make_icon_terrain_thicket() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var leaf := Color(0.22, 0.42, 0.18, 1.0)
	var leaf_dk := Color(0.15, 0.3, 0.12, 1.0)
	var leaf_lt := Color(0.32, 0.55, 0.24, 1.0)
	img.fill(leaf)
	fill_rect(img, 0, 0, 7, 7, leaf_lt)
	fill_rect(img, 8, 8, 15, 15, leaf_dk)
	fill_rect(img, 8, 0, 15, 7, leaf_dk)
	fill_rect(img, 0, 8, 7, 15, leaf_lt)
	return img

func make_icon_terrain_caltrops() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ground := Color(0.42, 0.4, 0.36, 1.0)
	var spike := Color(0.6, 0.6, 0.62, 1.0)
	var spike_hl := Color(0.8, 0.8, 0.82, 1.0)
	img.fill(ground)
	for pos in [Vector2i(3, 3), Vector2i(11, 4), Vector2i(5, 10), Vector2i(12, 12)]:
		set_px(img, pos.x, pos.y, spike)
		set_px(img, pos.x - 1, pos.y + 1, spike)
		set_px(img, pos.x + 1, pos.y + 1, spike)
		set_px(img, pos.x, pos.y - 1, spike_hl)
	return img

func make_icon_terrain_rubble() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ground := Color(0.3, 0.29, 0.27, 1.0)
	var chunk := Color(0.52, 0.5, 0.47, 1.0)
	var chunk_hl := Color(0.68, 0.66, 0.62, 1.0)
	img.fill(ground)
	fill_rect(img, 1, 2, 5, 6, chunk)
	fill_rect(img, 7, 5, 12, 10, chunk)
	fill_rect(img, 3, 10, 8, 14, chunk)
	fill_rect(img, 10, 1, 14, 4, chunk)
	set_px(img, 2, 2, chunk_hl)
	set_px(img, 8, 5, chunk_hl)
	set_px(img, 4, 10, chunk_hl)
	return img

func make_boss() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.06, 0.02, 0.02, 1.0)
	var O := Color(0.35, 0.12, 0.12, 1.0)
	var Od := Color(0.25, 0.08, 0.08, 1.0)
	var T := Color(0.95, 0.9, 0.8, 1.0)
	var E := Color(1.0, 0.85, 0.1, 1.0)
	var F := Color(0.15, 0.1, 0.08, 1.0)
	var W := Color(0.3, 0.18, 0.08, 1.0)
	var Wh := Color(0.55, 0.53, 0.55, 1.0)

	fill_rect(img, 1, 0, 14, 15, K)

	fill_rect(img, 4, 0, 11, 5, O)
	set_px(img, 5, 2, E)
	set_px(img, 10, 2, E)
	set_px(img, 5, 5, T)
	set_px(img, 10, 5, T)

	fill_rect(img, 2, 6, 13, 12, O)
	fill_rect(img, 2, 10, 13, 11, Od)
	fill_rect(img, 2, 12, 13, 12, F)

	fill_rect(img, 3, 13, 6, 15, O)
	fill_rect(img, 9, 13, 12, 15, O)
	fill_rect(img, 3, 15, 6, 15, K)
	fill_rect(img, 9, 15, 12, 15, K)

	fill_rect(img, 0, 7, 1, 11, O)
	fill_rect(img, 13, 7, 14, 11, O)

	fill_rect(img, 13, 8, 15, 14, W)
	fill_rect(img, 11, 4, 15, 8, Wh)

	return img

# Replaces make_boss() as the wave-boss from Main.gd:OWLBEAR_WAVE_START on --
# a round owl head (big eyes, hooked beak, feathered ear-tufts) on a bulky
# bear body with clawed feet.
# Placeholder art (World Progression feature, Beach) -- a simple many-eyed
# aquatic blob with trailing tentacles. Final art to be supplied later; this
# just needs to read as "distinct, aquatic, unsettling" at a glance.
func make_aboleth() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.1, 0.12, 1.0)
	var B := Color(0.25, 0.5, 0.55, 1.0)
	var Bd := Color(0.15, 0.35, 0.4, 1.0)
	var E := Color(1.0, 0.35, 0.9, 1.0)

	fill_rect(img, 2, 3, 14, 13, K)
	fill_rect(img, 3, 4, 13, 12, B)
	fill_rect(img, 3, 9, 13, 12, Bd)

	fill_rect(img, 1, 12, 3, 15, K)
	fill_rect(img, 6, 13, 8, 15, K)
	fill_rect(img, 12, 12, 14, 15, K)

	set_px(img, 5, 6, E)
	set_px(img, 8, 6, E)
	set_px(img, 11, 6, E)

	return img

# Placeholder art (World Progression feature, Beach) -- a humanoid mass of
# water with a wave-crest head and rippling body bands. Final art to be
# supplied later.
func make_water_elemental() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.15, 0.25, 1.0)
	var W := Color(0.3, 0.65, 0.95, 1.0)
	var Wl := Color(0.6, 0.85, 1.0, 1.0)
	var Wd := Color(0.15, 0.4, 0.65, 1.0)
	var E := Color(1.0, 1.0, 1.0, 1.0)

	fill_rect(img, 4, 1, 11, 5, K)
	fill_rect(img, 5, 2, 10, 4, W)
	set_px(img, 6, 3, E)
	set_px(img, 9, 3, E)

	fill_rect(img, 3, 5, 12, 14, K)
	fill_rect(img, 4, 6, 11, 13, W)
	fill_rect(img, 4, 8, 11, 9, Wl)
	fill_rect(img, 4, 11, 11, 12, Wd)

	fill_rect(img, 2, 14, 13, 15, Wd)

	return img

# Placeholder art (World Progression feature, Swamp) -- a squat green
# reptilian soldier with a crested head. Final art to be supplied later.
func make_lizard_soldier_swarm() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.15, 0.05, 1.0)
	var G := Color(0.3, 0.55, 0.2, 1.0)
	var Gd := Color(0.2, 0.4, 0.12, 1.0)
	var E := Color(1.0, 0.8, 0.1, 1.0)

	fill_rect(img, 4, 2, 11, 7, K)
	fill_rect(img, 5, 3, 10, 6, G)
	fill_rect(img, 3, 1, 5, 3, Gd)
	fill_rect(img, 10, 1, 12, 3, Gd)
	set_px(img, 6, 4, E)
	set_px(img, 9, 4, E)

	fill_rect(img, 3, 7, 12, 14, K)
	fill_rect(img, 4, 8, 11, 13, G)
	fill_rect(img, 4, 10, 11, 11, Gd)

	return img

# Placeholder art (World Progression feature, Swamp) -- a small winged
# dragon silhouette in a dark, swampy palette. Final art to be supplied
# later.
func make_black_dragonlet() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.03, 0.03, 0.04, 1.0)
	var D := Color(0.15, 0.18, 0.15, 1.0)
	var Dd := Color(0.08, 0.1, 0.08, 1.0)
	var E := Color(0.7, 0.1, 0.1, 1.0)

	fill_rect(img, 0, 5, 4, 9, K)
	fill_rect(img, 11, 5, 15, 9, K)
	fill_rect(img, 1, 6, 3, 8, D)
	fill_rect(img, 12, 6, 14, 8, D)

	fill_rect(img, 3, 2, 12, 12, K)
	fill_rect(img, 4, 3, 11, 11, D)
	fill_rect(img, 4, 7, 11, 9, Dd)
	set_px(img, 6, 4, E)
	set_px(img, 9, 4, E)

	fill_rect(img, 6, 12, 9, 15, Dd)

	return img

# Placeholder art (World Progression feature, Forest) -- a tree-shaped
# humanoid, brown trunk with a green leafy crown. Final art to be supplied
# later.
func make_treant() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.07, 0.03, 1.0)
	var Lf := Color(0.25, 0.5, 0.2, 1.0)
	var Lfd := Color(0.15, 0.38, 0.12, 1.0)
	var Br := Color(0.35, 0.22, 0.1, 1.0)
	var E := Color(1.0, 0.85, 0.3, 1.0)

	fill_rect(img, 1, 0, 14, 6, K)
	fill_rect(img, 2, 1, 13, 5, Lf)
	fill_rect(img, 2, 3, 13, 5, Lfd)

	fill_rect(img, 5, 6, 10, 13, K)
	fill_rect(img, 6, 7, 9, 12, Br)
	set_px(img, 7, 8, E)
	set_px(img, 8, 8, E)

	fill_rect(img, 3, 13, 6, 15, K)
	fill_rect(img, 9, 13, 12, 15, K)

	return img

# Placeholder art (World Progression feature, Forest) -- Treant's silhouette
# aged up: darker bark, a bigger and denser crown. Final art to be supplied
# later.
func make_elder_oak() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.06, 0.04, 0.02, 1.0)
	var Lf := Color(0.18, 0.4, 0.15, 1.0)
	var Lfd := Color(0.1, 0.28, 0.08, 1.0)
	var Br := Color(0.22, 0.14, 0.06, 1.0)
	var E := Color(1.0, 0.5, 0.1, 1.0)

	fill_rect(img, 0, 0, 15, 7, K)
	fill_rect(img, 1, 1, 14, 6, Lf)
	fill_rect(img, 1, 4, 14, 6, Lfd)

	fill_rect(img, 4, 7, 11, 14, K)
	fill_rect(img, 5, 8, 10, 13, Br)
	set_px(img, 6, 9, E)
	set_px(img, 9, 9, E)

	fill_rect(img, 2, 14, 5, 15, K)
	fill_rect(img, 10, 14, 13, 15, K)

	return img

# Placeholder art (World Progression feature, Desert) -- a many-eyed,
# many-mouthed pink blob. Final art to be supplied later.
func make_gibbering_mouther() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.05, 0.08, 1.0)
	var P := Color(0.75, 0.4, 0.5, 1.0)
	var Pd := Color(0.55, 0.25, 0.35, 1.0)
	var E := Color(1.0, 1.0, 0.3, 1.0)
	var T := Color(0.95, 0.95, 0.9, 1.0)

	fill_rect(img, 1, 3, 14, 13, K)
	fill_rect(img, 2, 4, 13, 12, P)
	fill_rect(img, 2, 9, 13, 12, Pd)

	set_px(img, 4, 6, E)
	set_px(img, 8, 5, E)
	set_px(img, 11, 6, E)
	fill_rect(img, 5, 9, 7, 10, T)
	fill_rect(img, 9, 9, 11, 10, T)

	return img

# Placeholder art (World Progression feature, Desert) -- a blocky grey
# construct with visible riveted plating. Final art to be supplied later.
func make_iron_golem() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.08, 0.09, 1.0)
	var Gr := Color(0.45, 0.45, 0.48, 1.0)
	var Grd := Color(0.3, 0.3, 0.33, 1.0)
	var Rv := Color(0.6, 0.5, 0.2, 1.0)
	var E := Color(1.0, 0.35, 0.1, 1.0)

	fill_rect(img, 3, 1, 12, 6, K)
	fill_rect(img, 4, 2, 11, 5, Gr)
	set_px(img, 6, 3, E)
	set_px(img, 9, 3, E)

	fill_rect(img, 1, 6, 14, 14, K)
	fill_rect(img, 2, 7, 13, 13, Gr)
	fill_rect(img, 2, 9, 13, 10, Grd)
	set_px(img, 3, 8, Rv)
	set_px(img, 12, 8, Rv)
	set_px(img, 3, 12, Rv)
	set_px(img, 12, 12, Rv)

	fill_rect(img, 1, 14, 5, 15, K)
	fill_rect(img, 10, 14, 14, 15, K)

	return img

# Placeholder art (World Progression feature, Caves) -- a hulking grey
# humanoid made of rock. Final art to be supplied later.
func make_stone_giant() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.1, 0.1, 1.0)
	var S := Color(0.5, 0.5, 0.52, 1.0)
	var Sd := Color(0.35, 0.35, 0.38, 1.0)
	var E := Color(1.0, 0.85, 0.4, 1.0)

	fill_rect(img, 4, 0, 11, 6, K)
	fill_rect(img, 5, 1, 10, 5, S)
	set_px(img, 6, 3, E)
	set_px(img, 9, 3, E)

	fill_rect(img, 1, 6, 14, 15, K)
	fill_rect(img, 2, 7, 13, 14, S)
	fill_rect(img, 2, 9, 13, 10, Sd)
	fill_rect(img, 2, 12, 5, 13, Sd)
	fill_rect(img, 10, 12, 13, 13, Sd)

	return img

# Placeholder art (World Progression feature, Caves) -- a floating orb with
# a giant central eye and several smaller eyestalks. Final art to be
# supplied later.
func make_beholder() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.05, 0.05, 1.0)
	var P := Color(0.55, 0.15, 0.2, 1.0)
	var Pd := Color(0.4, 0.1, 0.14, 1.0)
	var W := Color(0.95, 0.95, 0.9, 1.0)
	var Pu := Color(0.1, 0.1, 0.1, 1.0)

	fill_rect(img, 2, 2, 13, 13, K)
	fill_rect(img, 3, 3, 12, 12, P)
	fill_rect(img, 3, 8, 12, 12, Pd)

	fill_rect(img, 6, 6, 9, 9, W)
	set_px(img, 7, 7, Pu)
	set_px(img, 8, 7, Pu)

	set_px(img, 1, 1, W)
	set_px(img, 14, 1, W)
	set_px(img, 1, 6, W)
	set_px(img, 14, 6, W)

	return img

# Placeholder art (World Progression feature, Tundra) -- a hulking pale-blue
# humanoid dusted with frost. Final art to be supplied later.
func make_frost_giant() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.12, 0.15, 1.0)
	var Ic := Color(0.7, 0.85, 0.95, 1.0)
	var Icd := Color(0.5, 0.68, 0.8, 1.0)
	var E := Color(0.3, 0.9, 1.0, 1.0)

	fill_rect(img, 4, 0, 11, 6, K)
	fill_rect(img, 5, 1, 10, 5, Ic)
	set_px(img, 6, 3, E)
	set_px(img, 9, 3, E)

	fill_rect(img, 1, 6, 14, 15, K)
	fill_rect(img, 2, 7, 13, 14, Ic)
	fill_rect(img, 2, 9, 13, 10, Icd)
	fill_rect(img, 2, 12, 5, 13, Icd)
	fill_rect(img, 10, 12, 13, 13, Icd)

	return img

# Placeholder art (World Progression feature, Tundra) -- a small winged
# dragon silhouette in an icy white-blue palette, mirroring
# make_black_dragonlet's shape. Final art to be supplied later.
func make_white_dragon() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.5, 0.55, 0.6, 1.0)
	var D := Color(0.85, 0.9, 0.95, 1.0)
	var Dd := Color(0.7, 0.78, 0.85, 1.0)
	var E := Color(0.2, 0.6, 1.0, 1.0)

	fill_rect(img, 0, 5, 4, 9, K)
	fill_rect(img, 11, 5, 15, 9, K)
	fill_rect(img, 1, 6, 3, 8, D)
	fill_rect(img, 12, 6, 14, 8, D)

	fill_rect(img, 3, 2, 12, 12, K)
	fill_rect(img, 4, 3, 11, 11, D)
	fill_rect(img, 4, 7, 11, 9, Dd)
	set_px(img, 6, 4, E)
	set_px(img, 9, 4, E)

	fill_rect(img, 6, 12, 9, 15, Dd)

	return img

# Placeholder art (World Progression feature, Mountains) -- a giant bird of
# prey with broad outstretched wings. Final art to be supplied later.
func make_roc() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.1, 0.05, 1.0)
	var Fe := Color(0.5, 0.32, 0.15, 1.0)
	var Fed := Color(0.35, 0.22, 0.1, 1.0)
	var Bk := Color(0.9, 0.75, 0.2, 1.0)
	var E := Color(1.0, 0.9, 0.2, 1.0)

	fill_rect(img, 0, 4, 5, 9, K)
	fill_rect(img, 10, 4, 15, 9, K)
	fill_rect(img, 1, 5, 4, 8, Fe)
	fill_rect(img, 11, 5, 14, 8, Fe)

	fill_rect(img, 5, 2, 10, 11, K)
	fill_rect(img, 6, 3, 9, 10, Fe)
	fill_rect(img, 6, 7, 9, 9, Fed)
	set_px(img, 7, 4, E)
	fill_rect(img, 7, 5, 8, 5, Bk)

	fill_rect(img, 6, 11, 9, 14, Fed)

	return img

# Placeholder art (World Progression feature, Mountains) -- a winged dragon
# silhouette in an electric-blue palette, mirroring make_black_dragonlet's
# shape. Final art to be supplied later.
func make_blue_dragon() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.03, 0.05, 0.15, 1.0)
	var D := Color(0.15, 0.3, 0.7, 1.0)
	var Dd := Color(0.08, 0.18, 0.5, 1.0)
	var E := Color(0.9, 0.95, 1.0, 1.0)

	fill_rect(img, 0, 5, 4, 9, K)
	fill_rect(img, 11, 5, 15, 9, K)
	fill_rect(img, 1, 6, 3, 8, D)
	fill_rect(img, 12, 6, 14, 8, D)

	fill_rect(img, 3, 2, 12, 12, K)
	fill_rect(img, 4, 3, 11, 11, D)
	fill_rect(img, 4, 7, 11, 9, Dd)
	set_px(img, 6, 4, E)
	set_px(img, 9, 4, E)

	fill_rect(img, 6, 12, 9, 15, Dd)

	return img

# Placeholder art (World Progression feature, Volcano) -- a blocky humanoid
# construct with glowing lava cracks instead of Iron Golem's rivets. Final
# art to be supplied later.
func make_lava_golem() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.02, 0.02, 1.0)
	var Ro := Color(0.25, 0.15, 0.12, 1.0)
	var Rod := Color(0.15, 0.08, 0.06, 1.0)
	var Lv := Color(1.0, 0.45, 0.05, 1.0)

	fill_rect(img, 3, 1, 12, 6, K)
	fill_rect(img, 4, 2, 11, 5, Ro)
	set_px(img, 6, 3, Lv)
	set_px(img, 9, 3, Lv)

	fill_rect(img, 1, 6, 14, 14, K)
	fill_rect(img, 2, 7, 13, 13, Ro)
	fill_rect(img, 2, 9, 13, 10, Rod)
	set_px(img, 3, 8, Lv)
	set_px(img, 12, 8, Lv)
	set_px(img, 7, 11, Lv)
	set_px(img, 8, 11, Lv)

	fill_rect(img, 1, 14, 5, 15, K)
	fill_rect(img, 10, 14, 14, 15, K)

	return img

# Placeholder art (World Progression feature, Volcano) -- an ancient dragon
# silhouette, larger and more weathered than the other dragons, in a deep
# red palette. Final art to be supplied later.
func make_red_wyrm() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.02, 0.02, 1.0)
	var D := Color(0.55, 0.1, 0.08, 1.0)
	var Dd := Color(0.4, 0.06, 0.05, 1.0)
	var E := Color(1.0, 0.85, 0.2, 1.0)

	fill_rect(img, 0, 4, 4, 10, K)
	fill_rect(img, 11, 4, 15, 10, K)
	fill_rect(img, 1, 5, 3, 9, D)
	fill_rect(img, 12, 5, 14, 9, D)

	fill_rect(img, 2, 1, 13, 13, K)
	fill_rect(img, 3, 2, 12, 12, D)
	fill_rect(img, 3, 7, 12, 10, Dd)
	set_px(img, 5, 4, E)
	set_px(img, 10, 4, E)

	fill_rect(img, 5, 13, 10, 15, Dd)

	return img

# Placeholder art (World Progression feature, Voidlands) -- a winged
# creature wreathed in a dark void-purple glow. Final art to be supplied
# later.
func make_voidwing() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.02, 0.0, 0.05, 1.0)
	var V := Color(0.3, 0.1, 0.5, 1.0)
	var Vd := Color(0.18, 0.05, 0.32, 1.0)
	var E := Color(0.8, 0.3, 1.0, 1.0)

	fill_rect(img, 0, 3, 4, 8, K)
	fill_rect(img, 11, 3, 15, 8, K)
	fill_rect(img, 1, 4, 3, 7, V)
	fill_rect(img, 12, 4, 14, 7, V)

	fill_rect(img, 3, 2, 12, 12, K)
	fill_rect(img, 4, 3, 11, 11, V)
	fill_rect(img, 4, 7, 11, 9, Vd)
	set_px(img, 6, 4, E)
	set_px(img, 9, 4, E)

	fill_rect(img, 6, 12, 9, 15, Vd)

	return img

# Placeholder art (World Progression feature, Voidlands) -- a hooded robed
# spellcaster (Shaman/Druid's silhouette, per the established reuse
# convention) in a deep void-purple palette with a glowing orb staff. Final
# art to be supplied later. Reused as-is (same sprite, higher stats via
# power_tier) for the Nothingness boss-rush rematch.
func make_supreme_warlock() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.02, 0.08, 1.0)
	var R := Color(0.2, 0.08, 0.35, 1.0)
	var Rd := Color(0.12, 0.04, 0.22, 1.0)
	var Sk := Color(0.7, 0.6, 0.75, 1.0)
	var Or := Color(0.8, 0.3, 1.0, 1.0)

	fill_rect(img, 5, 1, 10, 5, K)
	fill_rect(img, 6, 2, 9, 4, Sk)
	fill_rect(img, 5, 0, 10, 2, R)

	fill_rect(img, 3, 5, 12, 15, K)
	fill_rect(img, 4, 6, 11, 14, R)
	fill_rect(img, 4, 10, 11, 14, Rd)

	fill_rect(img, 12, 3, 13, 13, K)
	set_px(img, 12, 3, Or)
	fill_rect(img, 11, 2, 14, 4, Or)

	return img

# Placeholder art (World Progression feature, Nothingness boss rush) -- a
# hulking dual-headed demon in a sickly dark-green palette. Final art to be
# supplied later.
func make_demogorgon() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.08, 0.03, 1.0)
	var G := Color(0.25, 0.35, 0.15, 1.0)
	var Gd := Color(0.15, 0.22, 0.08, 1.0)
	var E := Color(1.0, 0.2, 0.1, 1.0)

	fill_rect(img, 1, 1, 6, 6, K)
	fill_rect(img, 9, 1, 14, 6, K)
	fill_rect(img, 2, 2, 5, 5, G)
	fill_rect(img, 10, 2, 13, 5, G)
	set_px(img, 3, 3, E)
	set_px(img, 11, 3, E)

	fill_rect(img, 2, 6, 13, 15, K)
	fill_rect(img, 3, 7, 12, 14, G)
	fill_rect(img, 3, 10, 12, 12, Gd)

	return img

# Placeholder art (World Progression feature, Nothingness boss rush) -- a
# five-headed dragon queen, one head per chromatic hue. Final art to be
# supplied later.
func make_tiamat() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.05, 0.05, 1.0)
	var Body := Color(0.4, 0.1, 0.4, 1.0)
	var Bodyd := Color(0.28, 0.06, 0.28, 1.0)
	var Red := Color(0.8, 0.15, 0.1, 1.0)
	var Blue := Color(0.15, 0.3, 0.8, 1.0)
	var Green := Color(0.15, 0.6, 0.2, 1.0)
	var White := Color(0.9, 0.9, 0.95, 1.0)
	var Black := Color(0.2, 0.2, 0.2, 1.0)

	set_px(img, 2, 2, Red)
	set_px(img, 5, 1, White)
	set_px(img, 8, 1, Blue)
	set_px(img, 11, 1, Green)
	set_px(img, 14, 2, Black)

	fill_rect(img, 3, 3, 12, 13, K)
	fill_rect(img, 4, 4, 11, 12, Body)
	fill_rect(img, 4, 8, 11, 10, Bodyd)

	fill_rect(img, 6, 13, 9, 15, Bodyd)

	return img

# Placeholder art (World Progression feature, Nothingness boss rush) -- a
# pale-faced vampire lord in a dark red cape. Final art to be supplied later.
func make_count_strahd() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.05, 0.02, 0.02, 1.0)
	var Cp := Color(0.4, 0.05, 0.08, 1.0)
	var Cpd := Color(0.25, 0.02, 0.04, 1.0)
	var Sk := Color(0.85, 0.8, 0.78, 1.0)
	var E := Color(0.9, 0.1, 0.1, 1.0)

	fill_rect(img, 5, 1, 10, 6, K)
	fill_rect(img, 6, 2, 9, 5, Sk)
	set_px(img, 7, 3, E)
	set_px(img, 8, 3, E)

	fill_rect(img, 2, 5, 13, 15, K)
	fill_rect(img, 3, 6, 12, 14, Cp)
	fill_rect(img, 3, 10, 12, 14, Cpd)
	fill_rect(img, 6, 6, 9, 9, Sk)

	return img

# Placeholder art (World Progression feature, Nothingness boss rush) -- a
# regal, crowned frost giant king, icier and grander than Frost Giant. Final
# art to be supplied later.
func make_duke_zalto() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.1, 0.15, 1.0)
	var Ic := Color(0.6, 0.78, 0.95, 1.0)
	var Icd := Color(0.42, 0.6, 0.8, 1.0)
	var Cr := Color(1.0, 0.85, 0.2, 1.0)
	var E := Color(0.2, 1.0, 1.0, 1.0)

	fill_rect(img, 4, 0, 11, 2, Cr)
	fill_rect(img, 4, 1, 11, 6, K)
	fill_rect(img, 5, 2, 10, 5, Ic)
	set_px(img, 6, 3, E)
	set_px(img, 9, 3, E)

	fill_rect(img, 1, 6, 14, 15, K)
	fill_rect(img, 2, 7, 13, 14, Ic)
	fill_rect(img, 2, 9, 13, 10, Icd)
	fill_rect(img, 2, 12, 5, 13, Icd)
	fill_rect(img, 10, 12, 13, 13, Icd)

	return img

# Placeholder art (World Progression feature, Nothingness boss rush) -- a
# skeletal lich in a dark tattered robe with glowing green eyes. Final art
# to be supplied later.
func make_acererak() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.02, 0.02, 0.02, 1.0)
	var R := Color(0.12, 0.1, 0.15, 1.0)
	var Rd := Color(0.06, 0.05, 0.08, 1.0)
	var Bn := Color(0.85, 0.82, 0.75, 1.0)
	var E := Color(0.3, 1.0, 0.3, 1.0)

	fill_rect(img, 5, 1, 10, 5, K)
	fill_rect(img, 6, 2, 9, 4, Bn)
	set_px(img, 7, 3, E)
	set_px(img, 8, 3, E)

	fill_rect(img, 3, 5, 12, 15, K)
	fill_rect(img, 4, 6, 11, 14, R)
	fill_rect(img, 4, 10, 11, 14, Rd)

	fill_rect(img, 12, 4, 13, 12, K)
	set_px(img, 12, 4, E)

	return img

func make_owlbear() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.05, 0.03, 1.0)
	var F := Color(0.35, 0.22, 0.12, 1.0)
	var Fd := Color(0.24, 0.15, 0.08, 1.0)
	var Ft := Color(0.5, 0.38, 0.2, 1.0)
	var E := Color(1.0, 0.78, 0.1, 1.0)
	var Pupil := Color(0.05, 0.05, 0.05, 1.0)
	var Be := Color(0.15, 0.1, 0.08, 1.0)
	var Cl := Color(0.85, 0.8, 0.7, 1.0)

	# Feathered ear-tufts
	fill_rect(img, 2, 0, 4, 2, K)
	fill_rect(img, 11, 0, 13, 2, K)
	set_px(img, 3, 1, Ft)
	set_px(img, 12, 1, Ft)

	# Round owl head with two big eyes and a hooked beak
	fill_rect(img, 2, 1, 13, 8, K)
	fill_rect(img, 3, 2, 12, 7, F)
	fill_rect(img, 4, 3, 7, 6, K)
	fill_rect(img, 8, 3, 11, 6, K)
	fill_rect(img, 5, 4, 6, 5, E)
	fill_rect(img, 9, 4, 10, 5, E)
	set_px(img, 5, 4, Pupil)
	set_px(img, 9, 4, Pupil)
	fill_rect(img, 7, 6, 8, 8, Be)

	# Bulky bear body
	fill_rect(img, 1, 8, 14, 15, K)
	fill_rect(img, 2, 9, 13, 14, F)
	fill_rect(img, 2, 12, 13, 13, Fd)
	fill_rect(img, 4, 9, 11, 11, Ft)

	# Clawed feet
	fill_rect(img, 2, 14, 4, 15, Be)
	fill_rect(img, 11, 14, 13, 15, Be)
	set_px(img, 2, 15, Cl)
	set_px(img, 4, 15, Cl)
	set_px(img, 11, 15, Cl)
	set_px(img, 13, 15, Cl)

	return img

# Reworks make_archer()'s silhouette into a robed spellcaster: pointed hat,
# flowing robe, and a glowing-gem staff replacing the bow.
func make_apprentice_mage() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.08, 0.16, 1.0)
	var R := Color(0.28, 0.22, 0.55, 1.0)
	var Rd := Color(0.2, 0.15, 0.42, 1.0)
	var S := Color(0.85, 0.7, 0.55, 1.0)
	var E := Color(1.0, 1.0, 1.0, 1.0)
	var Staff := Color(0.4, 0.28, 0.15, 1.0)
	var Gem := Color(0.4, 0.85, 1.0, 1.0)

	# Pointed wizard hat
	set_px(img, 7, 0, K)
	fill_rect(img, 6, 1, 8, 1, K)
	fill_rect(img, 5, 2, 9, 2, K)
	fill_rect(img, 4, 3, 10, 3, K)

	# Head
	fill_rect(img, 5, 4, 10, 7, K)
	fill_rect(img, 6, 5, 9, 6, S)
	set_px(img, 7, 5, E)
	set_px(img, 8, 5, E)

	# Robe body
	fill_rect(img, 4, 7, 11, 14, K)
	fill_rect(img, 5, 8, 10, 13, R)
	fill_rect(img, 5, 11, 10, 12, Rd)

	fill_rect(img, 5, 14, 7, 15, K)
	fill_rect(img, 8, 14, 10, 15, K)

	fill_rect(img, 3, 9, 4, 12, R)
	fill_rect(img, 11, 9, 12, 12, R)

	# Staff held out, gem glowing at the top -- the caster's tell, replacing
	# the original Archer's bow silhouette.
	for i in 11:
		set_px(img, 13, 1 + i, Staff)
	fill_rect(img, 12, 0, 14, 1, Gem)

	return img

# Human torso trailing into a horse's body -- shared shape for both Centaur
# variants (see make_centaur_lancer/make_centaur_archer), which differ only
# in coat color and the weapon held out front.
func make_centaur_lancer() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.1, 0.08, 0.06, 1.0)
	var Hc := Color(0.55, 0.38, 0.2, 1.0)
	var Hd := Color(0.4, 0.27, 0.13, 1.0)
	var S := Color(0.82, 0.65, 0.5, 1.0)
	var Tu := Color(0.3, 0.25, 0.2, 1.0)
	var E := Color(0.05, 0.05, 0.05, 1.0)
	var Sh := Color(0.4, 0.28, 0.15, 1.0)
	var Sp := Color(0.6, 0.58, 0.55, 1.0)

	# Human head + torso, upper-left
	fill_rect(img, 2, 0, 7, 4, K)
	fill_rect(img, 3, 1, 6, 3, S)
	set_px(img, 4, 2, E)
	set_px(img, 5, 2, E)
	fill_rect(img, 1, 4, 8, 9, K)
	fill_rect(img, 2, 5, 7, 8, Tu)

	# Horse body trailing to the right
	fill_rect(img, 1, 8, 14, 13, K)
	fill_rect(img, 2, 9, 13, 12, Hc)
	fill_rect(img, 2, 11, 13, 12, Hd)

	# Tail
	fill_rect(img, 13, 9, 15, 12, K)
	fill_rect(img, 13, 10, 14, 11, Hc)

	# Four legs
	fill_rect(img, 2, 13, 3, 15, K)
	fill_rect(img, 5, 13, 6, 15, K)
	fill_rect(img, 9, 13, 10, 15, K)
	fill_rect(img, 12, 13, 13, 15, K)

	# Spear held forward and up -- the lancer's harder-hitting melee tell.
	draw_diag(img, 1, 9, 9, 1, Sh)
	fill_rect(img, 9, 0, 11, 1, Sp)

	return img

func make_centaur_archer() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.1, 0.08, 1.0)
	var Hc := Color(0.42, 0.4, 0.3, 1.0)
	var Hd := Color(0.3, 0.28, 0.2, 1.0)
	var S := Color(0.82, 0.65, 0.5, 1.0)
	var Tu := Color(0.24, 0.34, 0.2, 1.0)
	var E := Color(0.05, 0.05, 0.05, 1.0)
	var Bow := Color(0.45, 0.3, 0.15, 1.0)

	# Human head + torso, upper-left
	fill_rect(img, 2, 0, 7, 4, K)
	fill_rect(img, 3, 1, 6, 3, S)
	set_px(img, 4, 2, E)
	set_px(img, 5, 2, E)
	fill_rect(img, 1, 4, 8, 9, K)
	fill_rect(img, 2, 5, 7, 8, Tu)

	# Horse body trailing to the right
	fill_rect(img, 1, 8, 14, 13, K)
	fill_rect(img, 2, 9, 13, 12, Hc)
	fill_rect(img, 2, 11, 13, 12, Hd)

	# Tail
	fill_rect(img, 13, 9, 15, 12, K)
	fill_rect(img, 13, 10, 14, 11, Hc)

	# Four legs
	fill_rect(img, 2, 13, 3, 15, K)
	fill_rect(img, 5, 13, 6, 15, K)
	fill_rect(img, 9, 13, 10, 15, K)
	fill_rect(img, 12, 13, 13, 15, K)

	# Bow silhouette held out front -- the same tell the original Archer
	# used, now inherited by this variant.
	for i in 9:
		set_px(img, 0, 2 + i, Bow)
	set_px(img, 1, 3, Bow)
	set_px(img, 1, 9, Bow)

	return img

func make_fae_hut() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.15, 0.1, 0.06, 1.0)
	var Cap := Color(0.75, 0.25, 0.3, 1.0)
	var CapDk := Color(0.55, 0.15, 0.2, 1.0)
	var Spot := Color(0.95, 0.9, 0.8, 1.0)
	var Stem := Color(0.85, 0.78, 0.6, 1.0)
	var Door := Color(0.25, 0.16, 0.08, 1.0)
	var Glow := Color(0.95, 0.85, 0.4, 1.0)

	# A round mushroom-cap hut, not a humanoid -- distinguishes it visually
	# from every other enemy at a glance, matching how little it acts like
	# one (never attacks, barely moves).
	fill_rect(img, 3, 3, 12, 8, K)
	fill_rect(img, 4, 4, 11, 7, Cap)
	fill_rect(img, 4, 7, 11, 8, CapDk)
	set_px(img, 5, 5, Spot)
	set_px(img, 9, 5, Spot)
	set_px(img, 7, 6, Spot)

	fill_rect(img, 5, 9, 10, 14, K)
	fill_rect(img, 6, 10, 9, 14, Stem)
	fill_rect(img, 7, 11, 8, 13, Door)
	set_px(img, 6, 11, Glow)
	set_px(img, 9, 11, Glow)

	return img

func make_fae() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var Wing := Color(0.75, 0.9, 1.0, 0.55)
	var Body := Color(0.95, 0.85, 0.55, 1.0)
	var BodyDk := Color(0.85, 0.65, 0.35, 1.0)
	var Glow := Color(1.0, 0.98, 0.8, 1.0)

	# Tiny and mostly wing -- reads as fast/insubstantial even as a static
	# 16x16, fitting a Fae Hut's fleeting little minion.
	fill_rect(img, 1, 3, 6, 9, Wing)
	fill_rect(img, 9, 3, 14, 9, Wing)
	fill_rect(img, 6, 5, 9, 11, Body)
	fill_rect(img, 6, 9, 9, 11, BodyDk)
	set_px(img, 7, 6, Glow)
	set_px(img, 7, 12, Glow)
	set_px(img, 6, 13, Glow)
	set_px(img, 9, 13, Glow)

	return img

func make_gnome() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.12, 0.08, 0.06, 1.0)
	var Hat := Color(0.75, 0.15, 0.15, 1.0)
	var HatDk := Color(0.55, 0.08, 0.08, 1.0)
	var Skin := Color(0.9, 0.72, 0.55, 1.0)
	var Beard := Color(0.9, 0.9, 0.85, 1.0)
	var Robe := Color(0.3, 0.45, 0.3, 1.0)
	var RobeDk := Color(0.2, 0.32, 0.2, 1.0)

	# A classic pointy red cap makes it instantly readable at a glance,
	# especially clustered in a pack of up to 5 on the same grid.
	fill_rect(img, 6, 0, 9, 1, HatDk)
	fill_rect(img, 5, 2, 10, 4, Hat)
	fill_rect(img, 4, 5, 11, 6, HatDk)

	fill_rect(img, 5, 6, 10, 9, Skin)
	fill_rect(img, 4, 8, 11, 11, Beard)

	fill_rect(img, 3, 10, 12, 15, K)
	fill_rect(img, 4, 11, 11, 14, Robe)
	fill_rect(img, 4, 13, 11, 14, RobeDk)

	return img

func make_druid() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.08, 0.1, 0.06, 1.0)
	var R := Color(0.24, 0.4, 0.2, 1.0)
	var Rd := Color(0.16, 0.28, 0.13, 1.0)
	var S := Color(0.6, 0.55, 0.4, 1.0)
	var E := Color(0.85, 0.75, 0.25, 1.0)
	var Staff := Color(0.42, 0.3, 0.16, 1.0)
	var Leaf := Color(0.4, 0.7, 0.3, 1.0)

	# Deliberately close in silhouette to the Shaman (hood, robe, staff) --
	# same "support caster" archetype -- but a nature green/brown palette
	# and a leaf instead of an orb reads as a distinct identity at a glance.
	fill_rect(img, 5, 0, 10, 5, K)
	fill_rect(img, 6, 1, 9, 4, S)
	set_px(img, 7, 2, E)
	set_px(img, 8, 2, E)

	fill_rect(img, 3, 5, 12, 15, K)
	fill_rect(img, 4, 6, 11, 14, R)
	fill_rect(img, 4, 10, 11, 11, Rd)
	fill_rect(img, 4, 13, 11, 14, Rd)

	fill_rect(img, 2, 7, 3, 10, R)

	fill_rect(img, 12, 3, 13, 14, Staff)
	fill_rect(img, 11, 2, 14, 3, Leaf)
	set_px(img, 10, 1, Leaf)
	set_px(img, 13, 1, Leaf)

	return img

# Overworld decoration -- pure visual scatter, no collision. Taller than the
# other sprites (32px) so it reads as looming over the player instead of
# sitting at knee height.
func make_deco_tree() -> Image:
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var K := Color(0.18, 0.11, 0.06, 1.0)
	var Tk := Color(0.32, 0.2, 0.11, 1.0)
	var Cd := Color(0.09, 0.24, 0.09, 1.0)
	var Cm := Color(0.15, 0.36, 0.14, 1.0)
	var Cl := Color(0.24, 0.48, 0.2, 1.0)

	fill_rect(img, 9, 21, 14, 31, K)
	fill_rect(img, 10, 21, 13, 30, Tk)

	# A wide, stepped canopy silhouette (same "rounded via bands" technique
	# as draw_shield_shape, just asymmetric and much bigger).
	fill_rect(img, 7, 2, 16, 4, Cd)
	fill_rect(img, 4, 5, 19, 8, Cd)
	fill_rect(img, 1, 9, 22, 17, Cd)
	fill_rect(img, 3, 18, 20, 21, Cd)
	fill_rect(img, 6, 22, 17, 23, Cd)

	fill_rect(img, 3, 10, 12, 16, Cm)
	fill_rect(img, 5, 6, 15, 9, Cm)
	fill_rect(img, 4, 3, 13, 5, Cm)

	fill_rect(img, 4, 4, 9, 7, Cl)
	fill_rect(img, 2, 10, 7, 14, Cl)

	return img

func make_deco_bush() -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var Cd := Color(0.1, 0.26, 0.1, 1.0)
	var Cm := Color(0.16, 0.38, 0.15, 1.0)
	var Cl := Color(0.26, 0.5, 0.22, 1.0)

	fill_rect(img, 6, 2, 13, 3, Cd)
	fill_rect(img, 3, 4, 16, 7, Cd)
	fill_rect(img, 1, 8, 18, 11, Cd)
	fill_rect(img, 4, 12, 15, 13, Cd)

	fill_rect(img, 3, 5, 10, 8, Cm)
	fill_rect(img, 2, 9, 8, 10, Cm)

	fill_rect(img, 4, 5, 7, 6, Cl)

	return img

func make_deco_grass_tuft() -> Image:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var Bd := Color(0.14, 0.32, 0.12, 1.0)
	var Bl := Color(0.24, 0.46, 0.18, 1.0)
	var Flower := Color(0.95, 0.85, 0.35, 1.0)

	# A handful of angled blades, taller and more pronounced than the tiny
	# dashes tiled across GrassTile.png, so it reads as a standalone clump.
	fill_rect(img, 1, 6, 2, 11, Bd)
	fill_rect(img, 3, 3, 4, 11, Bl)
	fill_rect(img, 5, 5, 6, 11, Bd)
	fill_rect(img, 7, 2, 8, 11, Bl)
	fill_rect(img, 9, 6, 10, 11, Bd)

	set_px(img, 7, 1, Flower)
	set_px(img, 8, 2, Flower)

	return img

# A small boulder cluster -- overworld set dressing (Main.gd:_scatter_
# decorations), not the battle grid's own Rock terrain tile. Non-collidable,
# same as the bush/grass tuft, purely for visual variety in the scatter pool.
func make_deco_rock() -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var Sd := Color(0.35, 0.34, 0.33, 1.0)
	var Sm := Color(0.48, 0.47, 0.45, 1.0)
	var Sl := Color(0.62, 0.61, 0.58, 1.0)

	fill_rect(img, 1, 7, 8, 12, Sd)
	fill_rect(img, 6, 4, 15, 12, Sd)
	fill_rect(img, 13, 8, 18, 12, Sd)

	fill_rect(img, 2, 7, 7, 10, Sm)
	fill_rect(img, 7, 5, 13, 10, Sm)
	fill_rect(img, 14, 8, 17, 10, Sm)

	fill_rect(img, 8, 5, 11, 7, Sl)
	set_px(img, 3, 7, Sl)

	return img

# ---------------------------------------------------------------------
# Per-world overworld ground tiles (Main.gd:BIOME_GROUND) -- static, unlike
# grass_animated_texture's 3-frame sway, since a subtle animated sway reads
# right for grass specifically but not for sand/stone/ash/void. Full-bleed
# 16x16 tiles like the reserved battle terrain above, not padded icons.
# ---------------------------------------------------------------------

func make_ground_sand() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color(0.78, 0.68, 0.42, 1.0)
	var ripple := Color(0.68, 0.58, 0.34, 1.0)
	var hl := Color(0.86, 0.78, 0.52, 1.0)
	img.fill(base)
	for y in [2, 3, 9, 10]:
		for x in range(0, 16, 4):
			set_px(img, (x + y) % 16, y, ripple)
			set_px(img, (x + y + 1) % 16, y, ripple)
	set_px(img, 5, 6, hl)
	set_px(img, 12, 13, hl)
	return img

func make_ground_swamp() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var muck := Color(0.24, 0.26, 0.14, 1.0)
	var muck_dk := Color(0.16, 0.18, 0.09, 1.0)
	var water := Color(0.2, 0.3, 0.22, 1.0)
	img.fill(muck)
	fill_rect(img, 2, 3, 6, 6, water)
	fill_rect(img, 9, 8, 14, 12, water)
	fill_rect(img, 0, 12, 4, 15, muck_dk)
	fill_rect(img, 10, 1, 15, 4, muck_dk)
	return img

func make_ground_rock() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var stone := Color(0.42, 0.42, 0.44, 1.0)
	var crack := Color(0.3, 0.3, 0.32, 1.0)
	var hl := Color(0.55, 0.55, 0.58, 1.0)
	img.fill(stone)
	draw_diag(img, 1, 5, 5, 1, crack)
	draw_diag(img, 8, 14, 4, 1, crack)
	draw_diag(img, 10, 3, 4, 1, crack)
	set_px(img, 4, 2, hl)
	set_px(img, 12, 9, hl)
	return img

func make_ground_snow() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var snow := Color(0.88, 0.92, 0.96, 1.0)
	var shadow := Color(0.75, 0.82, 0.9, 1.0)
	var sparkle := Color(1.0, 1.0, 1.0, 1.0)
	img.fill(snow)
	fill_rect(img, 0, 11, 15, 15, shadow)
	fill_rect(img, 3, 4, 7, 6, shadow)
	set_px(img, 6, 2, sparkle)
	set_px(img, 11, 7, sparkle)
	set_px(img, 2, 9, sparkle)
	return img

func make_ground_ash() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ash := Color(0.18, 0.14, 0.12, 1.0)
	var ash_lt := Color(0.24, 0.19, 0.16, 1.0)
	var ember := Color(0.55, 0.25, 0.08, 1.0)
	img.fill(ash)
	fill_rect(img, 2, 2, 6, 5, ash_lt)
	fill_rect(img, 9, 8, 13, 11, ash_lt)
	set_px(img, 5, 10, ember)
	set_px(img, 11, 4, ember)
	return img

func make_ground_void() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color(0.08, 0.06, 0.14, 1.0)
	var base_dk := Color(0.04, 0.03, 0.08, 1.0)
	var star := Color(0.55, 0.4, 0.85, 1.0)
	img.fill(base)
	fill_rect(img, 0, 9, 15, 15, base_dk)
	set_px(img, 4, 3, star)
	set_px(img, 10, 6, star)
	set_px(img, 7, 12, star)
	return img

# ---------------------------------------------------------------------
# Castle town (Main.gd:_build_town) -- a small hub area spatially separate
# from the wilderness (see TOWN_AREA_ORIGIN), with a handful of walk-in
# buildings replacing the old auto-popup shop. Buildings share one basic
# cottage silhouette (_make_building_base) with a per-building accent color
# so they read as distinct at a glance.
# ---------------------------------------------------------------------

func make_ground_town() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var stone := Color(0.58, 0.56, 0.52, 1.0)
	var stone_dk := Color(0.48, 0.46, 0.42, 1.0)
	var stone_lt := Color(0.66, 0.64, 0.6, 1.0)
	img.fill(stone)
	# A simple offset cobblestone grid -- alternating rows of block seams.
	fill_rect(img, 0, 3, 15, 3, stone_dk)
	fill_rect(img, 0, 11, 15, 11, stone_dk)
	for x in [3, 11]:
		fill_rect(img, x, 0, x, 3, stone_dk)
	for x in [7, 15]:
		fill_rect(img, x, 4, x, 10, stone_dk)
	for x in [3, 11]:
		fill_rect(img, x, 12, x, 15, stone_dk)
	set_px(img, 2, 1, stone_lt)
	set_px(img, 9, 7, stone_lt)
	set_px(img, 13, 13, stone_lt)
	return img

func _make_building_base(roof_color: Color, roof_trim: Color) -> Image:
	var img := Image.create(40, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wall := Color(0.68, 0.56, 0.4, 1.0)
	var wall_dk := Color(0.56, 0.45, 0.32, 1.0)
	var door := Color(0.28, 0.18, 0.1, 1.0)

	fill_rect(img, 3, 20, 36, 46, wall)
	fill_rect(img, 3, 20, 36, 22, wall_dk)
	fill_rect(img, 3, 44, 36, 46, wall_dk)

	# Peaked roof -- narrowing tiers up to an apex.
	fill_rect(img, 1, 17, 38, 20, roof_color)
	fill_rect(img, 4, 14, 35, 17, roof_color)
	fill_rect(img, 7, 11, 32, 14, roof_color)
	fill_rect(img, 11, 8, 28, 11, roof_color)
	fill_rect(img, 15, 5, 24, 8, roof_color)
	fill_rect(img, 18, 2, 21, 5, roof_color)
	fill_rect(img, 1, 17, 38, 18, roof_trim)

	fill_rect(img, 16, 32, 23, 46, door)
	fill_rect(img, 17, 33, 22, 45, Color(0.2, 0.13, 0.07, 1.0))

	fill_rect(img, 7, 26, 12, 31, Color(0.55, 0.75, 0.85, 0.9))
	fill_rect(img, 27, 26, 32, 31, Color(0.55, 0.75, 0.85, 0.9))

	return img

func make_building_shop() -> Image:
	var img := _make_building_base(Color(0.55, 0.15, 0.12, 1.0), Color(0.4, 0.1, 0.08, 1.0))
	var gold := Color(0.95, 0.8, 0.25, 1.0)
	# A hanging sign board above the door.
	fill_rect(img, 14, 24, 25, 25, Color(0.3, 0.2, 0.1, 1.0))
	fill_rect(img, 15, 25, 24, 30, Color(0.4, 0.27, 0.15, 1.0))
	fill_rect(img, 17, 28, 21, 28, gold)
	set_px(img, 17, 27, gold)
	set_px(img, 19, 27, gold)
	set_px(img, 21, 27, gold)
	return img

func make_building_healer() -> Image:
	var img := _make_building_base(Color(0.85, 0.85, 0.82, 1.0), Color(0.7, 0.7, 0.68, 1.0))
	var red := Color(0.8, 0.15, 0.15, 1.0)
	# A red cross above the door.
	fill_rect(img, 18, 24, 21, 30, red)
	fill_rect(img, 15, 26, 24, 28, red)
	return img

func make_building_enchanter() -> Image:
	var img := _make_building_base(Color(0.32, 0.14, 0.45, 1.0), Color(0.22, 0.08, 0.32, 1.0))
	var glow := Color(0.75, 0.5, 0.95, 1.0)
	# A glowing arcane window in place of the shop's sign.
	fill_rect(img, 16, 24, 23, 31, Color(0.15, 0.06, 0.22, 1.0))
	fill_rect(img, 17, 25, 22, 30, glow)
	set_px(img, 19, 27, Color(0.95, 0.85, 1.0, 1.0))
	set_px(img, 20, 28, Color(0.95, 0.85, 1.0, 1.0))
	return img

func make_town_gate() -> Image:
	var img := Image.create(48, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.32, 0.22, 0.14, 1.0)
	var wood_lt := Color(0.42, 0.3, 0.19, 1.0)
	# Two posts and a lintel -- a simple wooden gateway marking the
	# wilderness-side entrance to town (see Main.gd:_build_town).
	fill_rect(img, 2, 4, 9, 39, wood)
	fill_rect(img, 3, 4, 8, 38, wood_lt)
	fill_rect(img, 38, 4, 45, 39, wood)
	fill_rect(img, 39, 4, 44, 38, wood_lt)
	fill_rect(img, 0, 0, 47, 7, wood)
	fill_rect(img, 2, 1, 45, 5, wood_lt)
	return img

# A tileable 16x16 stone wall texture for the town's visible perimeter (see
# Main.gd:_add_town_wall) -- previously the boundary was collision-only with
# no sprite at all. Deliberately a warmer, darker, higher-contrast palette
# than ground_town.png's cobblestone -- an earlier grey-on-grey version sat
# right next to that ground with barely any contrast and still read as
# "invisible" at a glance despite technically having a texture. Two brick
# courses with a lit top edge and shadowed bottom edge per brick, offset
# left/right like a real running bond, so it unmistakably reads as a raised
# wall rather than more flat paving.
func make_wall_town() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var stone := Color(0.42, 0.36, 0.28, 1.0)
	var stone_lt := Color(0.58, 0.5, 0.38, 1.0)
	var stone_dk := Color(0.26, 0.22, 0.16, 1.0)
	var mortar := Color(0.14, 0.11, 0.08, 1.0)
	img.fill(stone)
	fill_rect(img, 0, 0, 15, 1, mortar)
	fill_rect(img, 0, 8, 15, 9, mortar)
	fill_rect(img, 0, 15, 15, 15, mortar)
	fill_rect(img, 7, 1, 8, 7, mortar)
	fill_rect(img, 3, 9, 4, 14, mortar)
	fill_rect(img, 11, 9, 12, 14, mortar)
	fill_rect(img, 0, 2, 15, 3, stone_lt)
	fill_rect(img, 0, 10, 15, 11, stone_lt)
	fill_rect(img, 0, 6, 15, 7, stone_dk)
	fill_rect(img, 0, 13, 15, 14, stone_dk)
	return img

func make_building_tavern() -> Image:
	var img := _make_building_base(Color(0.45, 0.25, 0.12, 1.0), Color(0.32, 0.16, 0.06, 1.0))
	var mug_body := Color(0.75, 0.55, 0.3, 1.0)
	var foam := Color(0.95, 0.9, 0.8, 1.0)
	# A hanging tankard sign above the door in place of the shop's sign board.
	fill_rect(img, 14, 24, 25, 25, Color(0.3, 0.2, 0.1, 1.0))
	fill_rect(img, 16, 26, 21, 30, mug_body)
	fill_rect(img, 22, 27, 24, 29, mug_body)
	fill_rect(img, 16, 25, 21, 26, foam)
	return img

func make_building_beastiary() -> Image:
	var img := _make_building_base(Color(0.4, 0.38, 0.42, 1.0), Color(0.28, 0.26, 0.3, 1.0))
	var page := Color(0.85, 0.8, 0.65, 1.0)
	var spine := Color(0.3, 0.15, 0.1, 1.0)
	# A small open-book sign above the door.
	fill_rect(img, 13, 25, 26, 30, spine)
	fill_rect(img, 14, 26, 19, 29, page)
	fill_rect(img, 20, 26, 25, 29, page)
	return img

# The Enchanter's building, reflavored as an exiled wizard's tower -- taller
# and narrower than the standard cottage silhouette (_make_building_base),
# not built from it. make_building_enchanter() above is kept unused, same
# "superseded by better art, left as a fallback reference" convention as
# make_goblin().
func make_building_wizard_tower() -> Image:
	var img := Image.create(36, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color(0.42, 0.38, 0.48, 1.0)
	var stone_dk := Color(0.32, 0.28, 0.38, 1.0)
	var roof := Color(0.3, 0.12, 0.42, 1.0)
	var roof_trim := Color(0.2, 0.08, 0.3, 1.0)
	var glow := Color(0.75, 0.5, 0.95, 1.0)
	var orb := Color(0.85, 0.65, 1.0, 1.0)

	fill_rect(img, 8, 30, 27, 63, stone)
	fill_rect(img, 8, 30, 10, 63, stone_dk)
	fill_rect(img, 25, 30, 27, 63, stone_dk)
	fill_rect(img, 8, 61, 27, 63, stone_dk)

	# Steep conical roof, narrowing tiers to a point.
	fill_rect(img, 4, 26, 31, 30, roof)
	fill_rect(img, 7, 21, 28, 26, roof)
	fill_rect(img, 10, 16, 25, 21, roof)
	fill_rect(img, 13, 10, 22, 16, roof)
	fill_rect(img, 15, 4, 20, 10, roof)
	fill_rect(img, 17, 0, 18, 4, roof_trim)
	fill_rect(img, 4, 26, 31, 27, roof_trim)
	set_px(img, 17, 0, orb)
	set_px(img, 18, 0, orb)

	# A single glowing arcane window partway up.
	fill_rect(img, 14, 40, 21, 49, Color(0.15, 0.06, 0.22, 1.0))
	fill_rect(img, 15, 41, 20, 48, glow)
	set_px(img, 17, 44, Color(0.95, 0.85, 1.0, 1.0))
	set_px(img, 18, 45, Color(0.95, 0.85, 1.0, 1.0))

	fill_rect(img, 15, 55, 20, 63, Color(0.2, 0.13, 0.07, 1.0))
	return img

# A wooden bulletin board on two posts -- a kiosk object, not a full
# building, so it reads as a smaller stop-and-check-in landmark in town.
func make_quest_board() -> Image:
	var img := Image.create(28, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var post := Color(0.3, 0.2, 0.12, 1.0)
	var board := Color(0.45, 0.32, 0.2, 1.0)
	var board_dk := Color(0.4, 0.28, 0.17, 1.0)
	var paper := Color(0.85, 0.8, 0.65, 1.0)
	var paper2 := Color(0.8, 0.72, 0.5, 1.0)

	fill_rect(img, 3, 20, 6, 33, post)
	fill_rect(img, 21, 20, 24, 33, post)
	fill_rect(img, 1, 2, 26, 22, board)
	fill_rect(img, 2, 3, 25, 21, board_dk)

	fill_rect(img, 4, 5, 12, 12, paper)
	fill_rect(img, 15, 4, 23, 11, paper2)
	fill_rect(img, 6, 13, 14, 19, paper2)
	fill_rect(img, 16, 13, 24, 19, paper)
	set_px(img, 8, 8, post)
	set_px(img, 19, 7, post)
	return img

# Town centerpiece decoration -- placed by hand in _build_town, not part of
# the wilderness's random _scatter_decorations() pool.
func make_fountain() -> Image:
	var img := Image.create(40, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color(0.55, 0.55, 0.52, 1.0)
	var stone_dk := Color(0.42, 0.42, 0.4, 1.0)
	var water := Color(0.4, 0.65, 0.8, 0.9)
	var water_lt := Color(0.65, 0.85, 0.92, 0.9)

	fill_rect(img, 2, 20, 37, 33, stone_dk)
	fill_rect(img, 4, 18, 35, 31, stone)
	fill_rect(img, 6, 20, 33, 29, water)
	set_px(img, 10, 23, water_lt)
	set_px(img, 26, 25, water_lt)
	set_px(img, 18, 27, water_lt)

	fill_rect(img, 16, 6, 23, 20, stone_dk)
	fill_rect(img, 17, 7, 22, 18, stone)
	fill_rect(img, 12, 2, 27, 8, stone_dk)
	fill_rect(img, 13, 3, 26, 6, stone)
	fill_rect(img, 15, 0, 24, 2, water_lt)
	return img

func make_flower_bed() -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var soil := Color(0.3, 0.22, 0.14, 1.0)
	var leaf := Color(0.2, 0.4, 0.15, 1.0)
	var petal_red := Color(0.85, 0.25, 0.3, 1.0)
	var petal_yellow := Color(0.9, 0.8, 0.2, 1.0)
	var petal_pink := Color(0.9, 0.55, 0.7, 1.0)

	fill_rect(img, 0, 9, 19, 13, soil)
	fill_rect(img, 0, 7, 19, 9, leaf)
	set_px(img, 3, 6, petal_red)
	set_px(img, 7, 5, petal_yellow)
	set_px(img, 11, 6, petal_pink)
	set_px(img, 15, 5, petal_red)
	set_px(img, 5, 4, petal_yellow)
	set_px(img, 13, 4, petal_pink)
	return img

# The town's centerpiece landmark -- grander than the cottage-style
# buildings (_make_building_base), twin corner towers flanking a
# crenellated keep with a flag flying from the center. Purely decorative,
# same as every other building sprite (no collision -- see Main.gd:
# _place_building's convention).
func make_castle() -> Image:
	var img := Image.create(80, 72, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color(0.55, 0.54, 0.56, 1.0)
	var stone_dk := Color(0.42, 0.41, 0.44, 1.0)
	var stone_lt := Color(0.66, 0.65, 0.68, 1.0)
	var door := Color(0.25, 0.16, 0.09, 1.0)
	var tower_roof := Color(0.35, 0.14, 0.16, 1.0)
	var flag_pole := Color(0.3, 0.2, 0.12, 1.0)
	var flag := Color(0.75, 0.15, 0.15, 1.0)
	var gold := Color(0.9, 0.75, 0.3, 1.0)
	var window_glow := Color(0.95, 0.85, 0.45, 0.9)

	# Main keep body.
	fill_rect(img, 14, 24, 65, 71, stone)
	fill_rect(img, 14, 24, 65, 27, stone_dk)
	fill_rect(img, 14, 68, 65, 71, stone_dk)

	# Crenellated battlements along the top of the main keep.
	for x in range(14, 66, 8):
		fill_rect(img, x, 18, mini(x + 4, 65), 24, stone)
	fill_rect(img, 14, 22, 65, 24, stone_dk)

	# Left tower, taller than the keep, with its own tiny battlements and a
	# conical cap.
	fill_rect(img, 2, 14, 19, 71, stone)
	fill_rect(img, 2, 14, 5, 71, stone_dk)
	fill_rect(img, 16, 14, 19, 71, stone_dk)
	for x in [3, 7, 11, 15]:
		fill_rect(img, x, 8, x + 2, 14, stone)
	fill_rect(img, 0, 2, 21, 9, tower_roof)

	# Right tower, mirrored.
	fill_rect(img, 60, 14, 77, 71, stone)
	fill_rect(img, 60, 14, 63, 71, stone_dk)
	fill_rect(img, 74, 14, 77, 71, stone_dk)
	for x in [61, 65, 69, 73]:
		fill_rect(img, x, 8, x + 2, 14, stone)
	fill_rect(img, 58, 2, 79, 9, tower_roof)

	# Grand double doors at the base.
	fill_rect(img, 32, 50, 47, 71, door)
	fill_rect(img, 34, 52, 45, 69, Color(0.18, 0.11, 0.06, 1.0))
	set_px(img, 39, 60, stone_lt)

	# Glowing windows.
	fill_rect(img, 20, 34, 25, 40, window_glow)
	fill_rect(img, 54, 34, 59, 40, window_glow)
	fill_rect(img, 37, 34, 42, 40, window_glow)

	# A banner flying from the central battlement.
	fill_rect(img, 39, 4, 40, 20, flag_pole)
	fill_rect(img, 40, 4, 48, 12, flag)
	set_px(img, 48, 6, gold)
	set_px(img, 46, 8, gold)

	return img

func make_market_stall() -> Image:
	var img := Image.create(36, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var post := Color(0.35, 0.24, 0.15, 1.0)
	var awning := Color(0.7, 0.2, 0.2, 1.0)
	var awning_lt := Color(0.85, 0.85, 0.8, 1.0)
	var trim := Color(0.3, 0.1, 0.1, 1.0)
	var table := Color(0.5, 0.36, 0.22, 1.0)
	var goods1 := Color(0.8, 0.4, 0.2, 1.0)
	var goods2 := Color(0.5, 0.7, 0.3, 1.0)

	fill_rect(img, 2, 6, 5, 26, post)
	fill_rect(img, 30, 6, 33, 26, post)
	for i in 6:
		var x0 := i * 6
		var x1 := mini(x0 + 5, 35)
		fill_rect(img, x0, 0, x1, 5, awning if i % 2 == 0 else awning_lt)
	fill_rect(img, 0, 6, 35, 8, trim)

	fill_rect(img, 0, 22, 35, 26, table)
	fill_rect(img, 4, 16, 10, 22, goods1)
	fill_rect(img, 13, 17, 19, 22, goods2)
	fill_rect(img, 22, 16, 28, 22, goods1)
	return img

# The Butcher: standard cottage with a ham hanging above the door.
func make_building_butcher() -> Image:
	var img := _make_building_base(Color(0.5, 0.42, 0.28, 1.0), Color(0.38, 0.3, 0.2, 1.0))
	var board := Color(0.3, 0.2, 0.1, 1.0)
	var ham := Color(0.82, 0.38, 0.4, 1.0)
	var ham_dk := Color(0.62, 0.24, 0.28, 1.0)
	var bone := Color(0.92, 0.9, 0.8, 1.0)
	fill_rect(img, 14, 24, 25, 25, board)
	fill_rect(img, 15, 26, 22, 29, ham)
	fill_rect(img, 15, 29, 21, 30, ham_dk)
	fill_rect(img, 23, 27, 24, 28, bone)
	return img

# The Blacksmith: slate roof, an anvil hanging above the door, and a forge
# glowing orange in one window.
func make_building_blacksmith() -> Image:
	var img := _make_building_base(Color(0.3, 0.3, 0.34, 1.0), Color(0.2, 0.2, 0.24, 1.0))
	var bracket := Color(0.3, 0.2, 0.1, 1.0)
	var iron := Color(0.62, 0.64, 0.7, 1.0)
	var iron_dk := Color(0.34, 0.35, 0.4, 1.0)
	var glow := Color(0.95, 0.5, 0.15, 1.0)
	var glow_lt := Color(1.0, 0.85, 0.4, 1.0)
	fill_rect(img, 14, 24, 25, 25, bracket)
	# Anvil: horn, face, waist, base.
	fill_rect(img, 12, 26, 14, 26, iron)
	fill_rect(img, 15, 26, 24, 27, iron)
	fill_rect(img, 17, 28, 22, 29, iron_dk)
	fill_rect(img, 15, 30, 24, 31, iron)
	# The forge, glowing in the left window.
	fill_rect(img, 7, 26, 12, 31, glow)
	fill_rect(img, 8, 28, 11, 30, glow_lt)
	return img

# The Dojo: dark tiled roof with red trim and a red training banner (white
# roundel) hanging above the door.
func make_building_dojo() -> Image:
	var img := _make_building_base(Color(0.16, 0.16, 0.22, 1.0), Color(0.62, 0.12, 0.12, 1.0))
	var pole := Color(0.3, 0.2, 0.1, 1.0)
	var banner := Color(0.72, 0.13, 0.13, 1.0)
	var white := Color(0.95, 0.93, 0.88, 1.0)
	fill_rect(img, 14, 24, 25, 25, pole)
	fill_rect(img, 16, 25, 23, 31, banner)
	fill_rect(img, 18, 27, 21, 29, white)
	set_px(img, 19, 28, banner)
	set_px(img, 20, 28, banner)
	return img

# The Seer: a cottage under a deep-teal roof, a crystal ball glowing above the
# door, and a few stars scattered over the roof.
func make_building_seer() -> Image:
	var img := _make_building_base(Color(0.14, 0.28, 0.36, 1.0), Color(0.08, 0.18, 0.26, 1.0))
	var stand := Color(0.3, 0.2, 0.1, 1.0)
	var ball := Color(0.55, 0.75, 0.95, 1.0)
	var ball_lt := Color(0.92, 0.98, 1.0, 1.0)
	var star := Color(0.95, 0.85, 0.4, 1.0)
	fill_rect(img, 14, 24, 25, 25, stand)
	fill_rect(img, 17, 26, 22, 31, ball)
	fill_rect(img, 16, 27, 23, 30, ball)
	fill_rect(img, 18, 27, 19, 28, ball_lt)
	for p in [Vector2i(10, 13), Vector2i(29, 15), Vector2i(20, 9), Vector2i(14, 17), Vector2i(26, 11)]:
		set_px(img, p.x, p.y, star)
	return img

# The Wishing Well: a stone ring under a little red-tiled roof on two posts,
# with a rope and bucket over dark water.
func make_wishing_well() -> Image:
	var img := Image.create(24, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color(0.55, 0.55, 0.52, 1.0)
	var stone_dk := Color(0.4, 0.4, 0.38, 1.0)
	var stone_lt := Color(0.68, 0.68, 0.65, 1.0)
	var wood := Color(0.42, 0.28, 0.16, 1.0)
	var wood_dk := Color(0.3, 0.2, 0.11, 1.0)
	var roof := Color(0.55, 0.2, 0.16, 1.0)
	var roof_dk := Color(0.4, 0.13, 0.1, 1.0)
	var rope := Color(0.72, 0.62, 0.42, 1.0)
	var water := Color(0.22, 0.38, 0.6, 1.0)
	var water_lt := Color(0.5, 0.7, 0.9, 1.0)
	# Posts and roof.
	fill_rect(img, 3, 8, 4, 20, wood)
	fill_rect(img, 19, 8, 20, 20, wood)
	fill_rect(img, 1, 6, 22, 8, roof)
	fill_rect(img, 3, 4, 20, 6, roof)
	fill_rect(img, 6, 2, 17, 4, roof)
	fill_rect(img, 9, 0, 14, 2, roof)
	fill_rect(img, 1, 8, 22, 8, roof_dk)
	# Crank bar, rope, bucket.
	fill_rect(img, 4, 10, 19, 10, wood_dk)
	fill_rect(img, 11, 11, 11, 15, rope)
	fill_rect(img, 10, 16, 13, 18, wood)
	fill_rect(img, 10, 16, 13, 16, wood_dk)
	# Stone ring around dark water.
	fill_rect(img, 2, 19, 21, 27, stone_dk)
	fill_rect(img, 3, 19, 20, 26, stone)
	fill_rect(img, 3, 19, 20, 20, stone_lt)
	fill_rect(img, 6, 21, 17, 24, water)
	set_px(img, 9, 22, water_lt)
	set_px(img, 14, 23, water_lt)
	for x in [5, 11, 17]:
		set_px(img, x, 25, stone_dk)
	return img

# --- Racing grounds ---------------------------------------------------------

# A pale, side-on horse facing right -- drawn light on purpose so the panel and
# the infield can tint each one a different colour (modulate multiplies).
func make_icon_horse() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.16, 0.12, 0.1, 1.0)
	var coat := Color(0.94, 0.9, 0.82, 1.0)
	var coat_dk := Color(0.78, 0.72, 0.62, 1.0)
	var mane := Color(0.4, 0.34, 0.3, 1.0)
	# Body.
	fill_rect(img, 3, 5, 11, 10, K)
	fill_rect(img, 4, 6, 10, 9, coat)
	fill_rect(img, 4, 9, 10, 9, coat_dk)
	# Neck and head.
	fill_rect(img, 10, 2, 12, 7, K)
	fill_rect(img, 11, 3, 12, 6, coat)
	fill_rect(img, 12, 2, 15, 5, K)
	fill_rect(img, 12, 3, 14, 4, coat)
	set_px(img, 13, 3, K)
	fill_rect(img, 11, 1, 12, 1, K)
	# Mane and tail.
	fill_rect(img, 10, 2, 10, 6, mane)
	fill_rect(img, 1, 5, 2, 9, K)
	fill_rect(img, 1, 6, 2, 8, mane)
	# Legs and hooves.
	for x in [4, 6, 9, 10]:
		fill_rect(img, x, 10, x, 13, K)
		set_px(img, x, 11, coat)
		set_px(img, x, 12, coat)
	return img

# Packed race-track dirt: a tileable 16x16.
func make_ground_track() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var dirt := Color(0.62, 0.47, 0.3, 1.0)
	var dirt_dk := Color(0.52, 0.39, 0.24, 1.0)
	var dirt_lt := Color(0.7, 0.55, 0.36, 1.0)
	img.fill(dirt)
	for p in [Vector2i(2, 3), Vector2i(9, 1), Vector2i(13, 6), Vector2i(5, 10), Vector2i(11, 13), Vector2i(1, 14), Vector2i(7, 6)]:
		set_px(img, p.x, p.y, dirt_dk)
	for p in [Vector2i(4, 1), Vector2i(12, 3), Vector2i(8, 9), Vector2i(2, 7), Vector2i(14, 11), Vector2i(6, 14)]:
		set_px(img, p.x, p.y, dirt_lt)
	# A couple of hoofprint arcs.
	fill_rect(img, 3, 5, 4, 5, dirt_dk)
	fill_rect(img, 10, 11, 11, 11, dirt_dk)
	return img

# The grandstand: a striped awning over tiered seating full of tiny spectators.
func make_grandstand() -> Image:
	var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.42, 0.3, 0.18, 1.0)
	var wood_dk := Color(0.3, 0.2, 0.11, 1.0)
	var red := Color(0.72, 0.16, 0.16, 1.0)
	var cream := Color(0.92, 0.88, 0.78, 1.0)
	var flag := Color(0.95, 0.8, 0.2, 1.0)
	# Back wall and posts.
	fill_rect(img, 0, 8, 47, 31, wood_dk)
	fill_rect(img, 0, 8, 1, 31, wood)
	fill_rect(img, 46, 8, 47, 31, wood)
	# Striped awning.
	for i in 12:
		var x0 := i * 4
		fill_rect(img, x0, 4, x0 + 3, 9, red if i % 2 == 0 else cream)
	fill_rect(img, 0, 9, 47, 10, wood_dk)
	# Flags on the roof line.
	fill_rect(img, 3, 0, 3, 4, wood)
	fill_rect(img, 4, 0, 7, 2, flag)
	fill_rect(img, 43, 0, 43, 4, wood)
	fill_rect(img, 40, 0, 42, 2, flag)
	# Tiered benches with spectators.
	var crowd := [Color(0.9, 0.5, 0.4, 1.0), Color(0.4, 0.6, 0.9, 1.0), Color(0.5, 0.8, 0.45, 1.0), Color(0.9, 0.8, 0.4, 1.0), Color(0.8, 0.55, 0.85, 1.0)]
	for row in 3:
		var y := 13 + row * 6
		fill_rect(img, 3, y + 4, 44, y + 5, wood)
		for i in 9:
			var x := 5 + i * 4 + (row % 2) * 2
			var c: Color = crowd[(i + row * 2) % crowd.size()]
			fill_rect(img, x, y + 1, x + 1, y + 3, c)
			set_px(img, x, y, Color(0.95, 0.8, 0.65, 1.0))
	return img

# One gem-on-a-cord charm per talisman rarity (Talismans.gd picks the icon by
# rarity, so all 28 talismans share these four).
func make_icon_talisman(gem: Color, gem_lt: Color) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.12, 0.09, 0.06, 1.0)
	var cord := Color(0.6, 0.45, 0.22, 1.0)
	for p in [Vector2i(7, 0), Vector2i(8, 0), Vector2i(6, 1), Vector2i(9, 1), Vector2i(6, 2), Vector2i(9, 2), Vector2i(7, 3), Vector2i(8, 3)]:
		set_px(img, p.x, p.y, cord)
	# [row, x0, x1] outline then gem body -- a diamond.
	for row in [[4, 7, 8], [5, 6, 9], [6, 5, 10], [7, 4, 11], [8, 3, 12], [9, 3, 12], [10, 4, 11], [11, 5, 10], [12, 6, 9], [13, 7, 8]]:
		fill_rect(img, row[1], row[0], row[2], row[0], K)
	for row in [[5, 7, 8], [6, 6, 9], [7, 5, 10], [8, 4, 11], [9, 4, 11], [10, 5, 10], [11, 6, 9], [12, 7, 8]]:
		fill_rect(img, row[1], row[0], row[2], row[0], gem)
	set_px(img, 7, 6, gem_lt)
	set_px(img, 6, 7, gem_lt)
	set_px(img, 7, 7, gem_lt)
	return img

# --- Food and clothing icons (16x16, Foods.gd / Clothing.gd) -------------

func make_icon_food_meat() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.15, 0.08, 0.06, 1.0)
	var meat := Color(0.8, 0.36, 0.3, 1.0)
	var meat_dk := Color(0.6, 0.24, 0.2, 1.0)
	var fat := Color(0.95, 0.8, 0.7, 1.0)
	var bone := Color(0.95, 0.92, 0.82, 1.0)
	fill_rect(img, 3, 2, 10, 9, K)
	fill_rect(img, 4, 3, 9, 8, meat)
	fill_rect(img, 4, 6, 9, 8, meat_dk)
	set_px(img, 5, 4, fat)
	set_px(img, 6, 4, fat)
	set_px(img, 3, 2, Color(0, 0, 0, 0))
	set_px(img, 10, 2, Color(0, 0, 0, 0))
	fill_rect(img, 9, 8, 12, 11, K)
	fill_rect(img, 10, 9, 11, 10, bone)
	fill_rect(img, 11, 10, 14, 13, K)
	fill_rect(img, 12, 11, 13, 12, bone)
	return img

func make_icon_food_bread() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.2, 0.12, 0.06, 1.0)
	var crust := Color(0.78, 0.55, 0.25, 1.0)
	var crust_lt := Color(0.92, 0.75, 0.42, 1.0)
	var crust_dk := Color(0.6, 0.4, 0.18, 1.0)
	fill_rect(img, 2, 5, 13, 12, K)
	fill_rect(img, 3, 6, 12, 11, crust)
	fill_rect(img, 3, 6, 12, 7, crust_lt)
	fill_rect(img, 3, 10, 12, 11, crust_dk)
	set_px(img, 2, 5, Color(0, 0, 0, 0))
	set_px(img, 13, 5, Color(0, 0, 0, 0))
	for x in [5, 8, 11]:
		set_px(img, x, 8, crust_dk)
		set_px(img, x - 1, 9, crust_dk)
	return img

func make_icon_food_fish() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.08, 0.14, 0.2, 1.0)
	var body := Color(0.45, 0.65, 0.78, 1.0)
	var belly := Color(0.85, 0.9, 0.92, 1.0)
	var fin := Color(0.3, 0.5, 0.65, 1.0)
	fill_rect(img, 2, 5, 11, 11, K)
	fill_rect(img, 3, 6, 10, 10, body)
	fill_rect(img, 3, 9, 10, 10, belly)
	# Tail.
	fill_rect(img, 11, 6, 14, 6, K)
	fill_rect(img, 11, 10, 14, 10, K)
	fill_rect(img, 12, 7, 14, 9, fin)
	fill_rect(img, 11, 7, 11, 9, body)
	# Fin and eye.
	fill_rect(img, 6, 3, 8, 4, fin)
	set_px(img, 4, 7, K)
	return img

func make_icon_cloth_head() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.12, 0.09, 0.06, 1.0)
	var cloth := Color(0.55, 0.42, 0.28, 1.0)
	var cloth_lt := Color(0.7, 0.56, 0.38, 1.0)
	var cloth_dk := Color(0.4, 0.3, 0.2, 1.0)
	fill_rect(img, 4, 3, 11, 10, K)
	fill_rect(img, 5, 4, 10, 10, cloth)
	fill_rect(img, 5, 4, 8, 5, cloth_lt)
	fill_rect(img, 2, 10, 13, 12, K)
	fill_rect(img, 3, 10, 12, 11, cloth_dk)
	set_px(img, 4, 3, Color(0, 0, 0, 0))
	set_px(img, 11, 3, Color(0, 0, 0, 0))
	return img

func make_icon_cloth_body() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.12, 0.09, 0.06, 1.0)
	var cloth := Color(0.4, 0.5, 0.35, 1.0)
	var cloth_lt := Color(0.52, 0.62, 0.45, 1.0)
	var belt := Color(0.35, 0.22, 0.12, 1.0)
	fill_rect(img, 1, 3, 14, 5, K)
	fill_rect(img, 1, 3, 3, 9, K)
	fill_rect(img, 12, 3, 14, 9, K)
	fill_rect(img, 4, 3, 11, 14, K)
	fill_rect(img, 2, 4, 3, 8, cloth)
	fill_rect(img, 12, 4, 13, 8, cloth)
	fill_rect(img, 5, 4, 10, 13, cloth)
	fill_rect(img, 5, 4, 7, 6, cloth_lt)
	fill_rect(img, 7, 3, 8, 4, K)
	fill_rect(img, 5, 9, 10, 10, belt)
	return img

func make_icon_cloth_feet() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.12, 0.09, 0.06, 1.0)
	var leather := Color(0.5, 0.33, 0.18, 1.0)
	var leather_lt := Color(0.65, 0.45, 0.26, 1.0)
	var sole := Color(0.25, 0.16, 0.09, 1.0)
	fill_rect(img, 4, 1, 9, 11, K)
	fill_rect(img, 4, 9, 14, 13, K)
	fill_rect(img, 5, 2, 8, 10, leather)
	fill_rect(img, 5, 2, 6, 6, leather_lt)
	fill_rect(img, 5, 10, 13, 12, leather)
	fill_rect(img, 4, 12, 14, 13, sole)
	return img

# ---------------------------------------------------------------------
# Per-biome overworld decorations (Main.gd:BIOME_DECORATIONS) -- same
# transparent-background sprite convention as deco_tree/deco_bush/
# deco_grass_tuft/deco_rock above, just themed per biome.
# ---------------------------------------------------------------------

func make_deco_cactus() -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var Cd := Color(0.15, 0.35, 0.16, 1.0)
	var Cm := Color(0.22, 0.48, 0.22, 1.0)
	var Cl := Color(0.32, 0.6, 0.3, 1.0)
	var Spine := Color(0.85, 0.8, 0.6, 1.0)

	fill_rect(img, 6, 4, 9, 23, Cd)
	fill_rect(img, 7, 4, 8, 22, Cm)

	fill_rect(img, 2, 8, 5, 16, Cd)
	fill_rect(img, 3, 8, 4, 15, Cm)
	fill_rect(img, 2, 6, 5, 9, Cd)

	fill_rect(img, 10, 2, 13, 12, Cd)
	fill_rect(img, 11, 2, 12, 11, Cm)
	fill_rect(img, 10, 10, 13, 13, Cd)

	fill_rect(img, 7, 4, 8, 6, Cl)

	for y in range(5, 22, 3):
		set_px(img, 6, y, Spine)
		set_px(img, 9, y, Spine)

	return img

func make_deco_dead_tree() -> Image:
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.1, 0.08, 0.07, 1.0)
	var Tk := Color(0.24, 0.18, 0.14, 1.0)

	fill_rect(img, 10, 14, 13, 31, K)
	fill_rect(img, 11, 14, 12, 30, Tk)

	# Bare branches -- a mix of up-right (draw_diag's only direction) and
	# up-left (plotted by hand) strokes off the trunk at different heights,
	# for a gnarled, asymmetric silhouette instead of a tidy canopy.
	draw_diag(img, 12, 14, 6, 1, Tk)
	draw_diag(img, 12, 9, 4, 1, Tk)
	for i in 6:
		set_px(img, 11 - i, 13 - i, Tk)
	for i in 4:
		set_px(img, 10 - i, 7 - i, Tk)

	return img

func make_deco_pine_tree() -> Image:
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.1, 0.08, 0.07, 1.0)
	var Tk := Color(0.24, 0.18, 0.14, 1.0)
	var Gd := Color(0.08, 0.22, 0.14, 1.0)
	var Gm := Color(0.13, 0.32, 0.2, 1.0)
	var Snow := Color(0.88, 0.92, 0.96, 1.0)

	fill_rect(img, 10, 26, 13, 31, K)
	fill_rect(img, 11, 26, 12, 30, Tk)

	# Three stacked conical tiers, narrower toward the top.
	fill_rect(img, 4, 20, 19, 26, Gd)
	fill_rect(img, 6, 13, 17, 20, Gd)
	fill_rect(img, 8, 6, 15, 13, Gd)
	fill_rect(img, 10, 1, 13, 6, Gd)

	fill_rect(img, 5, 21, 18, 24, Gm)
	fill_rect(img, 7, 14, 16, 18, Gm)
	fill_rect(img, 9, 7, 14, 11, Gm)

	# Snow dusting along each tier's top edge.
	fill_rect(img, 4, 20, 19, 21, Snow)
	fill_rect(img, 6, 13, 17, 14, Snow)
	fill_rect(img, 8, 6, 15, 7, Snow)
	set_px(img, 11, 1, Snow)
	set_px(img, 12, 1, Snow)

	return img

func make_deco_crystal() -> Image:
	var img := Image.create(16, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var K := Color(0.12, 0.06, 0.22, 1.0)
	var P := Color(0.42, 0.25, 0.7, 1.0)
	var Pl := Color(0.62, 0.42, 0.9, 1.0)
	var Cy := Color(0.35, 0.75, 0.85, 1.0)

	fill_rect(img, 6, 0, 9, 17, K)
	fill_rect(img, 7, 1, 8, 16, P)
	fill_rect(img, 7, 1, 7, 6, Pl)

	fill_rect(img, 1, 8, 4, 17, K)
	fill_rect(img, 2, 9, 3, 16, Cy)
	fill_rect(img, 11, 6, 14, 17, K)
	fill_rect(img, 12, 7, 13, 16, Cy)

	return img

func _init() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")

	var barbarian := make_barbarian()
	barbarian.save_png("res://assets/barbarian.png")

	var blade_ally := make_blade_ally()
	blade_ally.save_png("res://assets/blade_ally.png")

	# enemy_goblin.png is NOT regenerated here anymore -- it's been replaced
	# with hand-drawn art (see Sprites/Goblin.png). make_goblin() is kept
	# below only as an unused fallback reference.

	var orc := make_orc()
	orc.save_png("res://assets/enemy_orc.png")

	var archer := make_archer()
	archer.save_png("res://assets/enemy_archer.png")

	var shaman := make_shaman()
	shaman.save_png("res://assets/enemy_shaman.png")

	var brute := make_brute()
	brute.save_png("res://assets/enemy_brute.png")

	var shade := make_shade()
	shade.save_png("res://assets/enemy_shade.png")

	var wolf := make_wolf()
	wolf.save_png("res://assets/enemy_wolf.png")

	var coin := make_coin()
	coin.save_png("res://assets/coin.png")

	var meat := make_meat()
	meat.save_png("res://assets/meat.png")

	var shard := make_runic_shard()
	shard.save_png("res://assets/runic_shard.png")

	make_toggle_off().save_png("res://assets/toggle_off.png")
	make_toggle_on().save_png("res://assets/toggle_on.png")

	make_icon_club().save_png("res://assets/weapon_club.png")
	make_icon_spear().save_png("res://assets/weapon_spear.png")
	make_icon_greatsword().save_png("res://assets/weapon_greatsword.png")
	make_icon_hammer().save_png("res://assets/weapon_hammer.png")
	make_icon_battle_axe().save_png("res://assets/weapon_battle_axe.png")
	make_icon_dagger().save_png("res://assets/weapon_dagger.png")
	make_icon_bow().save_png("res://assets/weapon_bow.png")
	make_icon_quiver().save_png("res://assets/quiver.png")
	make_icon_knuckle_gloves().save_png("res://assets/weapon_knuckle_gloves.png")
	make_icon_hand_picks().save_png("res://assets/weapon_hand_picks.png")

	make_icon_potion().save_png("res://assets/potion.png")

	make_icon_armor_rags().save_png("res://assets/armor_rags.png")
	make_icon_armor_leather().save_png("res://assets/armor_leather.png")
	make_icon_armor_iron().save_png("res://assets/armor_iron.png")
	make_icon_armor_steel().save_png("res://assets/armor_steel.png")
	make_icon_armor_dragonskin().save_png("res://assets/armor_dragonskin.png")
	make_icon_shield_wood().save_png("res://assets/shield_buckler.png")
	make_icon_shield_round().save_png("res://assets/shield_round.png")
	make_icon_shield_iron().save_png("res://assets/shield_bulwark.png")
	make_icon_shield_phantom().save_png("res://assets/shield_phantom.png")
	make_icon_shield_brawler().save_png("res://assets/shield_brawler.png")

	make_icon_terrain_ice().save_png("res://assets/terrain_ice.png")
	make_icon_terrain_embers().save_png("res://assets/terrain_embers.png")
	make_icon_terrain_poison_bog().save_png("res://assets/terrain_poison_bog.png")
	make_icon_terrain_quicksand().save_png("res://assets/terrain_quicksand.png")
	make_icon_terrain_spring().save_png("res://assets/terrain_spring.png")
	make_icon_terrain_crumbling().save_png("res://assets/terrain_crumbling.png")
	make_icon_terrain_thicket().save_png("res://assets/terrain_thicket.png")
	make_icon_terrain_caltrops().save_png("res://assets/terrain_caltrops.png")
	make_icon_terrain_rubble().save_png("res://assets/terrain_rubble.png")

	make_boss().save_png("res://assets/enemy_boss.png")
	make_owlbear().save_png("res://assets/enemy_owlbear.png")
	make_apprentice_mage().save_png("res://assets/enemy_apprentice_mage.png")
	make_centaur_lancer().save_png("res://assets/enemy_centaur_lancer.png")
	make_centaur_archer().save_png("res://assets/enemy_centaur_archer.png")

	make_fae_hut().save_png("res://assets/enemy_fae_hut.png")
	make_fae().save_png("res://assets/enemy_fae.png")
	make_gnome().save_png("res://assets/enemy_gnome.png")
	make_druid().save_png("res://assets/enemy_druid.png")

	make_aboleth().save_png("res://assets/enemy_aboleth.png")
	make_water_elemental().save_png("res://assets/enemy_water_elemental.png")

	make_lizard_soldier_swarm().save_png("res://assets/enemy_lizard_soldier_swarm.png")
	make_black_dragonlet().save_png("res://assets/enemy_black_dragonlet.png")
	make_treant().save_png("res://assets/enemy_treant.png")
	make_elder_oak().save_png("res://assets/enemy_elder_oak.png")
	make_gibbering_mouther().save_png("res://assets/enemy_gibbering_mouther.png")
	make_iron_golem().save_png("res://assets/enemy_iron_golem.png")

	make_stone_giant().save_png("res://assets/enemy_stone_giant.png")
	make_beholder().save_png("res://assets/enemy_beholder.png")
	make_frost_giant().save_png("res://assets/enemy_frost_giant.png")
	make_white_dragon().save_png("res://assets/enemy_white_dragon.png")
	make_roc().save_png("res://assets/enemy_roc.png")
	make_blue_dragon().save_png("res://assets/enemy_blue_dragon.png")

	make_lava_golem().save_png("res://assets/enemy_lava_golem.png")
	make_red_wyrm().save_png("res://assets/enemy_red_wyrm.png")

	make_voidwing().save_png("res://assets/enemy_voidwing.png")
	make_supreme_warlock().save_png("res://assets/enemy_supreme_warlock.png")

	make_demogorgon().save_png("res://assets/enemy_demogorgon.png")
	make_tiamat().save_png("res://assets/enemy_tiamat.png")
	make_count_strahd().save_png("res://assets/enemy_count_strahd.png")
	make_duke_zalto().save_png("res://assets/enemy_duke_zalto.png")
	make_acererak().save_png("res://assets/enemy_acererak.png")

	make_deco_tree().save_png("res://assets/deco_tree.png")
	make_deco_bush().save_png("res://assets/deco_bush.png")
	make_deco_grass_tuft().save_png("res://assets/deco_grass_tuft.png")
	make_deco_rock().save_png("res://assets/deco_rock.png")
	make_deco_cactus().save_png("res://assets/deco_cactus.png")
	make_deco_dead_tree().save_png("res://assets/deco_dead_tree.png")
	make_deco_pine_tree().save_png("res://assets/deco_pine_tree.png")
	make_deco_crystal().save_png("res://assets/deco_crystal.png")

	make_ground_sand().save_png("res://assets/ground_sand.png")
	make_ground_swamp().save_png("res://assets/ground_swamp.png")
	make_ground_rock().save_png("res://assets/ground_rock.png")
	make_ground_snow().save_png("res://assets/ground_snow.png")
	make_ground_ash().save_png("res://assets/ground_ash.png")
	make_ground_void().save_png("res://assets/ground_void.png")

	make_ground_town().save_png("res://assets/ground_town.png")
	make_building_shop().save_png("res://assets/building_shop.png")
	make_building_healer().save_png("res://assets/building_healer.png")
	make_building_enchanter().save_png("res://assets/building_enchanter.png")
	make_town_gate().save_png("res://assets/town_gate.png")
	make_wall_town().save_png("res://assets/wall_town.png")
	make_building_tavern().save_png("res://assets/building_tavern.png")
	make_building_beastiary().save_png("res://assets/building_beastiary.png")
	make_building_wizard_tower().save_png("res://assets/building_wizard_tower.png")
	make_quest_board().save_png("res://assets/quest_board.png")
	make_fountain().save_png("res://assets/fountain.png")
	make_flower_bed().save_png("res://assets/flower_bed.png")
	make_market_stall().save_png("res://assets/market_stall.png")
	make_castle().save_png("res://assets/castle.png")

	# Town expansion II: venues and their goods.
	make_building_butcher().save_png("res://assets/building_butcher.png")
	make_building_blacksmith().save_png("res://assets/building_blacksmith.png")
	make_building_dojo().save_png("res://assets/building_dojo.png")
	make_building_seer().save_png("res://assets/building_seer.png")
	make_wishing_well().save_png("res://assets/wishing_well.png")
	make_icon_horse().save_png("res://assets/horse.png")
	make_ground_track().save_png("res://assets/ground_track.png")
	make_grandstand().save_png("res://assets/grandstand.png")
	make_icon_talisman(Color(0.7, 0.7, 0.68, 1.0), Color(0.95, 0.95, 0.92, 1.0)).save_png("res://assets/talisman_common.png")
	make_icon_talisman(Color(0.3, 0.8, 0.4, 1.0), Color(0.75, 1.0, 0.8, 1.0)).save_png("res://assets/talisman_uncommon.png")
	make_icon_talisman(Color(0.3, 0.5, 0.95, 1.0), Color(0.75, 0.85, 1.0, 1.0)).save_png("res://assets/talisman_rare.png")
	make_icon_talisman(Color(0.75, 0.35, 0.95, 1.0), Color(0.95, 0.8, 1.0, 1.0)).save_png("res://assets/talisman_epic.png")
	make_icon_food_meat().save_png("res://assets/food_meat.png")
	make_icon_food_bread().save_png("res://assets/food_bread.png")
	make_icon_food_fish().save_png("res://assets/food_fish.png")
	make_icon_cloth_head().save_png("res://assets/cloth_head.png")
	make_icon_cloth_body().save_png("res://assets/cloth_body.png")
	make_icon_cloth_feet().save_png("res://assets/cloth_feet.png")

	print("sprites generated")
	quit()
