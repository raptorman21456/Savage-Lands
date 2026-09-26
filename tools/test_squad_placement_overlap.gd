extends SceneTree

# A tough squad (Orc-led, can include a Brute) is the worst case for
# footprint overlap: every unit lands in roughly the same column, so a 2x2
# Brute's row getting clamped down to fit the grid can silently land right
# on top of another squad member that legitimately claimed that row. Runs
# _setup_battle_grid directly, the same real path _gather_squad feeds into,
# across many trials with a maximal 4-unit squad including a Brute.
func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var orc_script = load("res://scripts/Orc.gd")
	var brute_script = load("res://scripts/Brute.gd")
	var goblin_script = load("res://scripts/Enemy.gd")

	var any_overlap := false
	var any_out_of_bounds := false
	var any_player_overlap := false
	var trials := 300
	for i in trials:
		var squad := [orc_script.new(), brute_script.new(), goblin_script.new(), goblin_script.new()]
		for e in squad:
			main.add_child(e)
		main._setup_battle_grid(squad)

		var claimed := {}
		claimed[main.battle_player_tile] = true
		for u in main.battle_units:
			for cell in main._footprint(u.tile, u.get("size", 1)):
				if not main._in_battle_bounds(cell):
					any_out_of_bounds = true
				if cell == main.battle_player_tile:
					any_player_overlap = true
				if claimed.has(cell):
					any_overlap = true
				claimed[cell] = true

		for e in squad:
			e.queue_free()
		await physics_frame

	print("no two squad members' footprints ever overlap across %d trials (Orc+Brute+2 Goblins each time): any_overlap=%s (expected false)" % [trials, any_overlap])
	print("no footprint ever lands on the player's own tile: any_player_overlap=%s (expected false)" % [any_player_overlap])
	print("every footprint cell stays within grid bounds: any_out_of_bounds=%s (expected false)" % [any_out_of_bounds])

	quit()
