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

	print("sprites generated")
	quit()
