extends SceneTree

# Overworld party followers (Main.gd:_update_party_followers) -- a recorded
# trail, no pathfinding/collision. Covers: no followers with an empty
# roster, one appears for a recruited Traitor Wolf, it visibly lags behind
# the player as they move, the roster rebuild only happens on an actual
# change (not every frame), and a fresh recruit snaps every follower to the
# player's current position instead of stretching a stale trail toward it.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	print("no followers with an empty roster: count=%d (expected 0)" % [main.party_follower_nodes.size()])

	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	main._process(0.016)
	print("a Traitor Wolf recruit spawns exactly one follower: count=%d (expected 1)" % [main.party_follower_nodes.size()])
	var signature_after_wolf: String = main.party_follower_signature

	# Moving the player should NOT immediately drag the follower along with
	# it -- it should lag behind by FOLLOWER_TRAIL_SPACING frames, same as a
	# real recorded-trail follow.
	var follower_start: Vector2 = main.party_follower_nodes[0].global_position
	var start_pos: Vector2 = player.global_position
	for i in main.FOLLOWER_TRAIL_SPACING - 2:
		player.global_position += Vector2(4, 0)
		main._process(0.016)
	print("the follower lags behind while the player is still mid-stride: follower_moved=%s (expected false, hasn't caught up yet)" % [
		not main.party_follower_nodes[0].global_position.is_equal_approx(follower_start)
	])

	# A few more frames past FOLLOWER_TRAIL_SPACING and it should now be
	# tracing the player's earlier path.
	for i in 4:
		player.global_position += Vector2(4, 0)
		main._process(0.016)
	print("...and eventually starts retracing the player's path: follower_moved=%s (expected true)" % [
		not main.party_follower_nodes[0].global_position.is_equal_approx(follower_start)
	])
	print("the follower never overtakes the player's own current position: behind_or_at=%s (expected true)" % [
		main.party_follower_nodes[0].global_position.x <= player.global_position.x
	])

	# Recruiting a Blade Ally adds a second follower -- and rebuilding the
	# roster snaps BOTH back to the player's current position, rather than
	# leaving the wolf's progress along the old trail in place while a brand
	# new second follower pops in at Vector2.ZERO.
	player.party_members.append({"name": "Blade Ally", "dmg_mult": 0.75})
	main._process(0.016)
	print("recruiting a Blade Ally adds a second follower: count=%d (expected 2), signature_changed=%s (expected true)" % [
		main.party_follower_nodes.size(), main.party_follower_signature != signature_after_wolf
	])
	var max_gap := 0.0
	for n in main.party_follower_nodes:
		max_gap = maxf(max_gap, n.global_position.distance_to(player.global_position))
	print("a fresh recruit snaps every follower to the player's current position: max_gap=%.1f (expected 0.0)" % [max_gap])

	# Re-processing with an unchanged roster must not rebuild the nodes
	# (same instance IDs survive).
	var node_id_before: int = main.party_follower_nodes[0].get_instance_id()
	main._process(0.016)
	print("an unchanged roster doesn't rebuild follower nodes: same_instance=%s (expected true)" % [
		main.party_follower_nodes[0].get_instance_id() == node_id_before
	])

	quit()
