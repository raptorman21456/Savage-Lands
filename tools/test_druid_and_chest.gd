extends SceneTree

# The Druid (caged in the Lizen camp until it is cleared out for the first time ever, then waiting in the HeartWood on
# every run) and the lighthouse's chest (a guaranteed Legendary weapon, once a run). See Main.gd's "The Druid" and
# "Chests" sections.

const SD := preload("res://scripts/SaveData.gd")
const WM := preload("res://scripts/WorldMap.gd")
const RM := preload("res://scripts/Rooms.gd")
const WP := preload("res://scripts/Weapons.gd")

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
	var original: Dictionary = SD.load_lifetime_data()
	SD.save_lifetime_data({})
	WM.ensure_built()
	var lizen: Vector2 = WM.landmark("lizen_encampment").pos
	var wood: Vector2 = WM.landmark("heartwood").pos

	# --- the first run: she is in a cage in the Lizen camp
	var main = await _fresh_main()
	print("Not yet unlocked: %s (expected false)" % [SD.is_druid_unlocked()])
	print("The Druid stands in the Lizen camp: %.0f px from its centre (expected 330), in a cage: %s (expected true)" % [main.druid_npc.position.distance_to(lizen), main.druid_cage != null])
	main._on_druid_touched()
	print("Walking up to her while she is caged does not recruit her: party %s (expected [])" % [_kinds(main)])
	var fort: Dictionary = RM.room_at(lizen)
	print("The fort refills with enemies while its warlord stands: spawn closed=%s (expected false)" % [main._room_spawn_closed(fort)])

	# --- clearing it out: the warlord down AND the fort empty
	main.defeated_landmark_bosses["lizen_encampment"] = true
	var defender = main._spawn_one_enemy(main.EnemyScript, lizen + Vector2(200, 200))
	main.enemies_alive += 1
	main._check_lizen_camp_cleared()
	print("With the warlord down but a defender still standing, the camp is not cleared: %s (expected false), unlocked %s (expected false)" % [main.lizen_camp_cleared, SD.is_druid_unlocked()])
	defender.free()
	main.enemies_alive = 0
	main._check_lizen_camp_cleared()
	print("...and once the last defender is gone it is: cleared=%s (expected true), unlocked for good=%s (expected true)" % [main.lizen_camp_cleared, SD.is_druid_unlocked()])
	print("The cage is gone and the Druid is in your party: cage=%s (expected null), party %s (expected [druid]), she has left the camp: %s (expected true)" % [main.druid_cage, _kinds(main), main.druid_npc == null])
	main.player.global_position = lizen + Vector2(0, 700)
	var misses := 0
	for i in 60:
		var spot: Dictionary = main._regional_spawn_spot(true)
		if not spot.is_empty() and spot.room.id == fort.id:
			misses += 1
	print("A cleared fort stays cleared: spawn closed=%s (expected true), spawn spots chosen inside it in 60 tries: %d (expected 0)" % [main._room_spawn_closed(fort), misses])
	main.queue_free()
	await process_frame

	# --- a full party: she is freed and unlocked, but waits at the camp until there is room
	SD.save_lifetime_data({})
	main = await _fresh_main()
	main.player.max_party_slots = 0
	main.defeated_landmark_bosses["lizen_encampment"] = true
	main._check_lizen_camp_cleared()
	print("With no room in the party she is freed and unlocked but not recruited: cage=%s (expected null), unlocked %s (expected true), party %s (expected [])" % [main.druid_cage, SD.is_druid_unlocked(), _kinds(main)])
	main.player.max_party_slots = 2
	main._on_druid_touched()
	print("...and joins when you come back with room: party %s (expected [druid])" % [_kinds(main)])
	main.queue_free()
	await process_frame

	# --- a later run: unlocked, so she waits in the HeartWood (no cage, no camp to clear)
	main = await _fresh_main()
	var far: float = main.druid_npc.position.distance_to(wood)
	var in_room: bool = RM.room_at(main.druid_npc.position).id == RM.room_at(wood).id
	print("On a later run she waits in the HeartWood: %.0f px from the tree (expected 816), in its room %s (expected true), in a cage %s (expected false)" % [far, in_room, main.druid_cage != null])
	var layout = RM.layout(RM.room_at(wood))
	print("...on open ground: floor depth %.0f (expected over 150)" % [layout.sample(main.druid_npc.position)])
	main._on_druid_touched()
	print("Walking up to her recruits her without clearing anything: party %s (expected [druid]), camp cleared this run %s (expected false)" % [_kinds(main), main.lizen_camp_cleared])
	main.queue_free()
	await process_frame

	# --- the lighthouse chest
	main = await _fresh_main()
	var legendary_ok := true
	var staff_or_wood := false
	for i in 300:
		var w: Dictionary = WP.make_legendary()
		if w.tier_name != "Legendary":
			legendary_ok = false
		if w.get("material_id", "") == "wood" or WP.is_ally_only(w):
			staff_or_wood = true
		if WP.get_owned_variant(w.id).is_empty():
			legendary_ok = false
	print("Every chest roll is a Legendary a player can wield, never a Staff or Wooden: tiers ok=%s (expected true), staff or wood seen=%s (expected false)" % [legendary_ok, staff_or_wood])
	var before: int = main.player.owned_weapons.size()
	var door: Dictionary = main.OverworldMapScript.gull_buildings()[0]
	main.player.global_position = door.door + Vector2(0, 40.0)
	await physics_frame
	main.player.global_position = door.door
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	var room = main._get_interior("gull_lighthouse")
	var chest: Array = room.def.chests[0]
	print("Walk into the lighthouse door: in_interior=%s (expected true), room '%s' (expected The Lighthouse)" % [main.in_interior, main.hud.world_label.text])
	main.player.global_position = room.origin + Vector2(float(chest[1]), float(chest[2]) + 120.0)
	await physics_frame
	main.player.global_position = room.origin + Vector2(float(chest[1]), float(chest[2]) + 64.0)
	await physics_frame
	await physics_frame
	await physics_frame
	var found: Array = main.player.owned_weapons.keys().filter(func(k): return str(k).contains("_legendary_"))
	var variant: Dictionary = WP.get_owned_variant(str(found[0])) if found.size() > 0 else {}
	print("Walking up to the chest gives one Legendary weapon: found %s (expected 1 id), tier %s (expected Legendary), collection grew by %d (expected 1)" % [found.size(), variant.get("tier_name", ""), main.player.owned_weapons.size() - before])
	print("...and the chest is open: %s (expected true), %s" % [main.opened_chests.has("gull_lighthouse"), main.hud.message_label.text])
	main.player.global_position = room.origin + Vector2(float(chest[1]), float(chest[2]) + 130.0)
	await physics_frame
	main.player.global_position = room.origin + Vector2(float(chest[1]), float(chest[2]) + 64.0)
	await physics_frame
	await physics_frame
	await physics_frame
	print("A second visit finds it empty: still %d Legendary (expected 1)" % [main.player.owned_weapons.keys().filter(func(k): return str(k).contains("_legendary_")).size()])
	main.queue_free()
	await process_frame
	main = await _fresh_main()
	print("On a new run the chest is shut again: opened chests %s (expected {})" % [main.opened_chests])

	SD.save_lifetime_data(original)
	quit()
