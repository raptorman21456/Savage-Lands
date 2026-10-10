extends SceneTree

# The world map's data and geometry (scripts/WorldMap.gd): size, regions and their paint order, the places the
# user described, region lookup, blocked water and danger tiers.

const WM := preload("res://scripts/WorldMap.gd")

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	WM.ensure_built()
	print("Building the whole map takes well under a second: %d ms (expected < 1500)" % [Time.get_ticks_msec() - t0])
	print("The map is 7x the old one each way: %s (expected (33600, 23800))" % [WM.SIZE])
	var ids := []
	for r in WM.regions:
		ids.append(r.id)
	print("Regions in paint order: %s" % [ids])
	var inside := true
	for r in WM.regions:
		for p in r.polygon:
			if p.x < -0.5 or p.y < -0.5 or p.x > WM.SIZE.x + 0.5 or p.y > WM.SIZE.y + 0.5:
				inside = false
	print("Every region stays on the map: %s (expected true)" % [inside])

	# --- the places the user described
	var centre: Vector2 = WM.SIZE / 2.0
	print("The middle of the map is the Great Expanse: %s (expected great_expanse)" % [WM.region_at(centre).id])
	print("The castle town landmark is dead centre: %s (expected %s)" % [WM.landmark("town").pos, centre])
	var spawn: Vector2 = WM.spawn_position()
	print("You spawn on the inner edge of the woods, toward the middle: region %s (expected woods_edge), tier %d (expected 1)" % [WM.region_at(spawn).id, WM.region_at(spawn).tier])
	print("...in the top-left quarter of the map: %s (expected true)" % [spawn.x < WM.SIZE.x / 2.0 and spawn.y < WM.SIZE.y / 2.0])
	var woods_pos: Vector2 = WM.landmark("heartwood").pos
	print("The HeartWood stands at the heart of the woods: region %s (expected heartwood_grove)" % [WM.region_at(woods_pos).id])
	print("...with the massive woods around it (a deep-wood point): %s (expected woods)" % [WM.region_at(Vector2(0.28, 0.12) * WM.SIZE).id])
	var ruins: Vector2 = WM.landmark("ruins").pos
	print("The ruined settlement is top-centre, a little left, east of the woods: region %s (expected ruins), x=%.2f (expected 0.4-0.5), right of the woods: %s" % [WM.region_at(ruins).id, ruins.x / WM.SIZE.x, ruins.x > WM.landmark("heartwood").pos.x])
	print("The Lizen Encampment is below the woods on the far left: region %s (expected lizen), below the woods: %s, far left: %s" % [WM.region_at(WM.landmark("lizen_encampment").pos).id, WM.landmark("lizen_encampment").pos.y > woods_pos.y, WM.landmark("lizen_encampment").pos.x / WM.SIZE.x < 0.15])
	print("The swamp lies below the encampment: %s (expected swamp)" % [WM.region_at(Vector2(0.10, 0.65) * WM.SIZE).id])
	print("The bottom-left corner is ocean: %s (expected ocean)" % [WM.region_at(Vector2(0.03, 0.97) * WM.SIZE).id])
	print("...with beaches between it and the land: %s (expected beach)" % [WM.region_at(Vector2(0.03, 0.735) * WM.SIZE).id])
	print("Pesca is a dock town on a headland out in the water: region %s (expected pesca), and the sea beside it is still ocean: %s (expected ocean)" % [WM.region_at(WM.landmark("pesca").pos).id, WM.region_at(Vector2(0.14, 0.90) * WM.SIZE).id])
	print("The very bottom of the map (middle) is the Frozen Wastes: %s (expected frozen_wastes)" % [WM.region_at(Vector2(0.55, 0.99) * WM.SIZE).id])
	print("The bottom-right corner is the Voidlands: %s (expected voidlands)" % [WM.region_at(Vector2(0.98, 0.98) * WM.SIZE).id])
	print("The top right has a massive volcano: crater %s (expected crater), its slopes %s (expected volcano_slopes), ringed by rocky hills %s (expected volcano_hills)" % [WM.region_at(Vector2(0.69, 0.17) * WM.SIZE).id, WM.region_at(Vector2(0.69, 0.17) * WM.SIZE + Vector2(2600, 0)).id, WM.region_at(Vector2(0.69, 0.17) * WM.SIZE + Vector2(4200, 0)).id])
	print("East of the volcano is the desert: %s (expected desert)" % [WM.region_at(Vector2(0.93, 0.2) * WM.SIZE).id])
	print("The mountains moved down the east side below the desert: %s (expected mountains)" % [WM.region_at(Vector2(0.92, 0.46) * WM.SIZE).id])
	print("...and the Voidlands swallow their southern half: %s (expected voidlands)" % [WM.region_at(Vector2(0.92, 0.70) * WM.SIZE).id])
	print("The ranch is on the town's outskirts: %s (expected ranch), %.0f px from the centre (expected 1000-6000)" % [WM.region_at(WM.landmark("ranch").pos).id, WM.landmark("ranch").pos.distance_to(centre)])

	# --- the rules
	var tiers := {}
	for r in WM.regions:
		tiers[r.id] = r.tier
	print("Danger tiers: spawn woods edge %d, Great Expanse %d, woods %d, desert %d, Frozen Wastes %d, Voidlands %d (expected 1 1 2 4 5 8)" % [tiers.woods_edge, tiers.great_expanse, tiers.woods, tiers.desert, tiers.frozen_wastes, tiers.voidlands])
	var hardest: int = 0
	for r in WM.regions:
		hardest = maxi(hardest, int(r.tier))
	print("The Voidlands are the hardest place: %s (expected true)" % [hardest == tiers.voidlands])
	print("Tier power climbs: %s (expected true)" % [WM.tier_power(1) < WM.tier_power(4) and WM.tier_power(4) < WM.tier_power(8)])
	print("Deep water cannot be walked, land can: ocean blocked=%s (expected true), spawn blocked=%s (expected false), Pesca blocked=%s (expected false)" % [WM.is_blocked(Vector2(0.03, 0.97) * WM.SIZE), WM.is_blocked(spawn), WM.is_blocked(WM.landmark("pesca").pos)])
	var polys: Array = WM.blocked_polygons()
	var blocked_area := 0.0
	for p in polys:
		blocked_area += absf(WM._area(p))
	var ocean_area: float = absf(WM._area(WM.region("ocean").polygon))
	print("The sea's collision has the Pesca headland cut out: %d piece(s), %.1f%% of the ocean's outline (expected 1 piece, under 100%%)" % [polys.size(), blocked_area / ocean_area * 100.0])
	var pesca_in_water := false
	for p in polys:
		if Geometry2D.is_point_in_polygon(WM.landmark("pesca").pos, p):
			pesca_in_water = true
	print("...so Pesca stands on solid ground: %s (expected false)" % [pesca_in_water])
	var missing := []
	for r in WM.regions:
		if r.walkable and r.enemies.is_empty() and not (r.id in ["pesca", "ranch"]):
			missing.append(r.id)
	print("Every walkable region except the safe ones has an enemy table: missing %s (expected [])" % [missing])
	print("Pesca and the ranch are safe (no wild enemies): %s (expected true)" % [WM.region("pesca").enemies.is_empty() and WM.region("ranch").enemies.is_empty()])
	var bosses := []
	for l in WM.landmarks:
		if l.boss != "":
			bosses.append(l.boss)
	print("Six bosses guard six landmarks: %s (expected 6: elder_oak, lizen_warband, leviathan, white_dragon, red_wyrm, archmage)" % [bosses])
	var same := true
	var wobble_a: PackedVector2Array = WM.region("woods").polygon
	same = wobble_a.size() > 40
	print("Borders are wobbled into natural outlines (the woods has plenty of corners): %d (expected > 40)" % [wobble_a.size()])
	quit()
