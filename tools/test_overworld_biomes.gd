extends SceneTree

# Per-world overworld ground/decoration system (Main.gd:BIOME_GROUND/
# BIOME_DECORATIONS/_rebuild_overworld_biome) -- real per-biome assets
# swapped in on an actual world change, not just a tint on the same grass
# everywhere.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	print("boots on Plains' grass biome, no rebuild needed: current_biome_built=%s (expected grass)" % main.current_biome_built)
	var boot_deco_count: int = main.deco_nodes.size()
	print("boot scatter already ran once: deco_nodes=%d (expected > 0)" % boot_deco_count)

	# Staying in the same world across a wave transition (still Plains,
	# still "grass") must NOT tear down and rescatter the whole overworld --
	# same node instances, same count.
	var first_deco_ref = main.deco_nodes[0]
	main.current_world_index = 0
	main._apply_world_visuals()
	await physics_frame
	print("no biome change -> no rebuild: deco_nodes unchanged=%s count_unchanged=%s (expected true, true)" % [
		main.deco_nodes[0] == first_deco_ref, main.deco_nodes.size() == boot_deco_count
	])

	# Crossing into Tundra (a real biome change, "grass" -> "snow") tears
	# down the old grass decorations and their collision bodies, swaps the
	# ground texture to the snow tile, and rescatters snow's own set
	# (pine_tree + rock, see BIOME_DECORATIONS).
	var old_collision_count: int = main.deco_collision_nodes.size()
	main.current_world_index = 6
	main._apply_world_visuals()
	await physics_frame
	await physics_frame
	print("crossing into Tundra rebuilds: current_biome_built=%s (expected snow), deco_nodes.size=%d (expected 24)" % [
		main.current_biome_built, main.deco_nodes.size()
	])
	print("ground texture swapped to the snow tile, not grass_animated_texture: %s (expected true)" % [
		main.ground.texture == main.BIOME_GROUND["snow"]
	])
	print("old grass decorations were actually freed, not just forgotten: %s (expected true)" % [
		not is_instance_valid(first_deco_ref)
	])
	# Pine trees are collidable (see BIOME_DECORATIONS) -- confirms the old
	# tree-trunk collision bodies got cleared too, not leaked/doubled up.
	print("collision bodies rebuilt (not leaked from the old grass set): new_count=%d (expected == count of pine_tree specs, 14)" % [
		main.deco_collision_nodes.size()
	])

	# Rebuilding must never place a decoration on top of the player's actual
	# current position (not just the world's center) -- move the player
	# somewhere specific, cross into another biome, and confirm nothing
	# landed within the same clearance radius used for the initial spawn.
	main.player.global_position = Vector2(600, 400)
	main.current_world_index = 4
	main._apply_world_visuals()
	await physics_frame
	await physics_frame
	var too_close := false
	for deco in main.deco_nodes:
		if is_instance_valid(deco) and deco.global_position.distance_to(main.player.global_position) < main.DECO_PLAYER_CLEARANCE:
			too_close = true
	print("rebuilding never drops a decoration on the player's actual live position: %s (expected false)" % too_close)

	# Grass biome recurs later (Forest, index 3) -- confirms switching BACK
	# into a grass biome re-swaps to the shared animated texture correctly,
	# not stuck on whatever static tile the last biome used.
	main.current_world_index = 3
	main._apply_world_visuals()
	await physics_frame
	print("switching back into a grass biome (Forest) re-swaps to the shared animated texture: %s (expected true)" % [
		main.ground.texture == main.hud.grass_animated_texture
	])

	quit()
