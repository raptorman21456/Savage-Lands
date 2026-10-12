extends SceneTree

# Things found out in the world rather than bought: the Knight in the ruins (once Friends in High Places puts him within
# reach), the four found talismans (Ember Charm in the Lava Causeway, Wildfire Core in the Crater, Stone Amulet in the
# Old Mine, Lucky Clover by luck on the plains), and fishing at Pesca (bait, fish, rods; fish sell for far less there).
# See Main.gd's Knight / Lucky Clover / Chests sections, FishmongerPanel.gd and FishingHole.gd.

const WM := preload("res://scripts/WorldMap.gd")
const RM := preload("res://scripts/Rooms.gd")
const TAL := preload("res://scripts/Talismans.gd")
const FOODS := preload("res://scripts/Foods.gd")
const HOLE := preload("res://scripts/FishingHole.gd")
const IN := preload("res://scripts/Interior.gd")

func _fresh_main() -> Node:
	var m = load("res://Main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await physics_frame
	await physics_frame
	for e in m.get_tree().get_nodes_in_group("enemies"):
		e.free()
	m.enemies_alive = 0
	return m

func _kinds(main) -> Array:
	return main.player.party.map(func(p): return p.kind)

func _init() -> void:
	seed(20261011)
	var main = await _fresh_main()
	var player = main.player

	# --- the Knight
	print("Without Friends in High Places there is no Knight to find: %s (expected null)" % [main.knight_npc])
	player.meta_battle_hardened = true
	main._build_knight()
	var ruins: Vector2 = WM.landmark("ruins").pos
	print("With it he stands in the Ruined Settlement: %.0f px from its centre (expected 430)" % [main.knight_npc.position.distance_to(ruins)])
	var layout = RM.layout(RM.room_at(ruins))
	print("...on open ground: floor depth %.0f (expected over 150)" % [layout.sample(main.knight_npc.position)])
	player.max_party_slots = 0
	main._on_knight_touched()
	print("A full party can't take him: party %s (expected []), still there: %s (expected true)" % [_kinds(main), main.knight_npc != null])
	player.max_party_slots = 2
	main._on_knight_touched()
	print("Walking up to him recruits him: party %s (expected [knight]), he has left the ruins: %s (expected true)" % [_kinds(main), main.knight_npc == null])
	print("No flat placeholder Knight any more: %d (expected 0)" % [player.party_members.filter(func(m): return m.get("name", "") == "Knight").size()])
	main.queue_free()
	await process_frame
	main = await _fresh_main()
	player = main.player
	main.apply_meta_purchase("battle_hardened")
	print("Buying Friends in High Places mid-run brings him out: %s (expected true)" % [main.knight_npc != null])

	# --- the found talismans: none is ever sold
	var found := ["ember_charm", "wildfire_core", "stone_amulet", "lucky_clover"]
	print("Four talismans are found, not sold: %s (expected true)" % [found.all(func(id): return TAL.get_talisman(id).get("found", false))])
	var chest_spots: Dictionary = main._world_chest_spots()
	var floor_ok := true
	for id in chest_spots:
		var at: Vector2 = chest_spots[id]
		var l = RM.layout(RM.room_at(at))
		if l.sample(at) < 150.0 or WM.is_blocked(at):
			floor_ok = false
	print("The two chests out in the world stand on open ground: %s (expected true); the Lava Causeway's is in room '%s' (expected The Lava Causeway), the Crater's in '%s' (expected The Crater)" % [floor_ok, RM.room_at(chest_spots.lava_causeway).name, RM.room_at(chest_spots.crater).name])
	player.level = 20                                   # slots for them all
	for id in ["lava_causeway", "crater"]:
		var expect: String = main.CHEST_CONTENTS[id].id
		main._open_chest(id)
		print("The %s chest gives the %s: owned %s (expected true), worn %s (expected true), chest shows open %s (expected true)" % [id, expect, player.owned_talismans.has(expect), player.equipped_talismans.has(expect), main.world_chests[id].open.visible])
	var count_before: int = player.owned_talismans.size()
	main._open_chest("crater")
	print("A chest gives nothing twice: %d -> %d talismans (expected equal)" % [count_before, player.owned_talismans.size()])
	# the Old Mine's chest, in a room
	var door: Dictionary = main.OverworldMapScript.cave_buildings()[0]
	main._interior_busy = false
	main.player.global_position = door.door + Vector2(0, 40.0)
	await physics_frame
	main.player.global_position = door.door
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	var room = main._get_interior("cave_mine")
	var chest: Array = room.def.chests[0]
	main.player.global_position = room.origin + Vector2(float(chest[1]), float(chest[2]) + 120.0)
	await physics_frame
	main.player.global_position = room.origin + Vector2(float(chest[1]), float(chest[2]) + 64.0)
	await physics_frame
	await physics_frame
	await physics_frame
	await physics_frame
	print("The Old Mine's chest holds the Stone Amulet: in '%s' (expected The Old Mine), owned %s (expected true)" % [main.hud.world_label.text, player.owned_talismans.has("stone_amulet")])
	main.queue_free()
	await process_frame
	main = await _fresh_main()
	print("On a new run every chest is shut again: %s (expected {}), talismans owned %d (expected 0)" % [main.opened_chests, main.player.owned_talismans.size()])
	player = main.player

	# --- the Lucky Clover: 1 in 1000 for every 100 px walked on the plains
	var plains := Vector2(18000.0, 15600.0)
	print("The test spot is on the Great Expanse: %s (expected great_expanse), not protected: %s (expected false)" % [WM.region_at(plains).id, main._in_protected_zone(plains)])
	var trials := 150
	var total_steps := 0
	for t in trials:
		main.player.owned_talismans.erase("lucky_clover")
		main._clover_last_pos = Vector2.INF
		main._clover_walked = 0.0
		var steps := 0
		while not main.player.owned_talismans.has("lucky_clover") and steps < 20000:
			main.player.global_position = plains + Vector2(100.0 * float(steps % 2), 0.0)
			main._roll_lucky_clover()
			steps += 1
		total_steps += steps
	var mean: float = float(total_steps) / float(trials)
	print("Walking the plains turns one up after about 1000 steps of 100 px: mean %.0f over %d trials (expected 750-1250)" % [mean, trials])
	main.player.owned_talismans.erase("lucky_clover")
	main._clover_last_pos = Vector2.INF
	var wood := Vector2(5000.0, 9000.0)
	var in_woods := false
	for i in 6000:
		main.player.global_position = wood + Vector2(100.0 * float(i % 2), 0.0)
		main._roll_lucky_clover()
		if main.player.owned_talismans.has("lucky_clover"):
			in_woods = true
	print("Walking in the woods (%s) never does: %s (expected false)" % [WM.region_at(wood).id, in_woods])
	main._clover_last_pos = Vector2.INF
	var jumped := false
	for i in 4000:
		main.player.global_position = plains + Vector2(5000.0 * float(i % 2), 0.0)    # jumps, not walking
		main._roll_lucky_clover()
		if main.player.owned_talismans.has("lucky_clover"):
			jumped = true
	print("A jump across the map is not walking: %s (expected false)" % [jumped])

	# --- fishing at Pesca
	print("The town has no fishing hole any more: %s (expected false)" % [main.TOWN_LAYOUT.has("fishing")])
	var spot: Dictionary = main.OverworldMapScript.pesca_fishing_spot()
	var spot_ok: bool = not WM.is_blocked(spot.pos) and RM.layout(RM.room_at(spot.pos)).sample(spot.pos) > 100.0 and WM.region_at(spot.pos).id == "pesca"
	print("Pesca's fishing spot is on its south shore on open ground: %s (expected true)" % [spot_ok])
	main.player.global_position = spot.pos + Vector2(0, 110.0)
	await physics_frame
	main.player.global_position = spot.pos
	await physics_frame
	await physics_frame
	print("Walking onto the jetty opens the fishing panel: visible=%s (expected true)" % [main.town_panels.fishing.visible])
	player = main.player
	player.bait = 0
	player.coins = 1000
	var panel = main.town_panels.fishing
	panel.rng = RandomNumberGenerator.new()
	panel.rng.seed = 7
	print("With no bait you cannot cast: %s (expected false)" % [panel.cast()])
	panel.close()
	var mong = main.town_panels.fishmonger
	player.coins = 1000
	mong.open(player)
	print("The Fishmonger's panel opens: visible=%s (expected true)" % [mong.visible])
	print("Bait costs %d coins (expected %d), a tin of %d costs %d (expected %d)" % [HOLE.BAIT_PRICE, 6, HOLE.BAIT_PACK, HOLE.BAIT_PACK_PRICE, 27])
	var c0: int = player.coins
	mong.buy_bait(1)
	mong.buy_bait(HOLE.BAIT_PACK)
	print("Buying bait: bait %d (expected 6), coins spent %d (expected 33)" % [player.bait, c0 - player.coins])
	c0 = player.coins
	print("Buying a Grilled Bass: ok=%s (expected true), costs %d (expected 24), in the bag: %s (expected true)" % [mong.buy_fish("food_bass"), c0 - player.coins, player.potion_queue.has("food_bass")])
	player.add_potion("food_minnow")
	player.add_potion("food_minnow")
	print("Fish sell for a lot less at Pesca: minnow %d vs the Butcher's %d, bass %d vs %d (expected 2 vs 8, 5 vs 20)" % [FOODS.sell_price("food_minnow", true), FOODS.sell_price("food_minnow", false), FOODS.sell_price("food_bass", true), FOODS.sell_price("food_bass", false)])
	c0 = player.coins
	print("Selling a minnow to the Fishmonger pays %d (expected 2), leaves %d minnow (expected 1)" % [(mong.sell("food_minnow") as int) * (player.coins - c0), player.potion_queue.count("food_minnow")])
	mong.close()
	var butcher = main.town_panels.butcher
	butcher.open(player)
	c0 = player.coins
	butcher.sell("food_minnow")
	print("The town's Butcher pays %d for the same fish (expected 8)" % [player.coins - c0])
	print("...and nothing for what you do not have: %s (expected false)" % [butcher.sell("food_minnow")])
	butcher.close()
	mong.open(player)
	print("The default rod is the Driftwood Rod: %s (expected Driftwood Rod)" % [player.fishing_rod().name])
	c0 = player.coins
	print("Buying the Oakwood Rod: ok=%s (expected true), costs %d (expected 150), now fishing with %s (expected Oakwood Rod)" % [mong.buy_rod("rod_oak"), c0 - player.coins, player.fishing_rod().name])
	print("...and not twice: %s (expected false)" % [mong.buy_rod("rod_oak")])
	player.coins = 10
	print("Too poor for the Golden Rod: %s (expected false)" % [mong.buy_rod("rod_golden")])
	mong.close()
	print("A better rod widens the bite window (%d -> %d ticks) and eases the line (tension step %.3f -> %.3f)" % [
		HOLE.bite_window_ticks(0.0, 0), HOLE.bite_window_ticks(0.0, int(HOLE.rod("rod_oak").window_ticks)),
		HOLE.step_reel(0.0, 0.0, "large", true, RandomNumberGenerator.new(), 1.0).tension - 0.0,
		HOLE.step_reel(0.0, 0.0, "large", true, RandomNumberGenerator.new(), float(HOLE.rod("rod_golden").tension_mult)).tension])
	player.bait = 3
	main.town_panels.fishing.open(player)
	var bait_before: int = player.bait
	print("A cast uses one bait: %s (expected true), %d -> %d" % [main.town_panels.fishing.cast(), bait_before, player.bait])
	main.town_panels.fishing.close()
	# Pesca's Fishmonger's counter opens his panel
	var fish_door: Dictionary = main.OverworldMapScript.pesca_buildings()[2]
	print("The Fishmonger's house is the third on the boardwalk and trades as a fishmonger: %s (expected pesca_fish / fishmonger)" % ["%s / %s" % [fish_door.interior, IN.venue_of(fish_door.interior)]])
	quit()
