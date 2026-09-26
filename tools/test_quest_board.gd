extends SceneTree

# Quest Board (Main.gd:quest_slots/_roll_quest/_build_quest/_quest_progress/
# accept_quest/is_quest_complete/claim_quest). All 3 templates are driven by
# counters that already exist and update themselves during normal play
# (run_kills_by_name, total_kills, player.coins) -- no new tracking.

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
	print("boots with exactly 3 quest slots: %d (expected 3)" % [main.quest_slots.size()])

	var templates := []
	var seen_targets := {}
	var has_duplicate_target := false
	for slot in main.quest_slots:
		templates.append(slot.template)
		if slot.template == "cull_the_herd":
			if seen_targets.has(slot.target_name):
				has_duplicate_target = true
			seen_targets[slot.target_name] = true
	print("no two slots share the same (template, target_name) pair: %s (expected true)" % [not has_duplicate_target])

	# --- Cull the Herd: progress = kills of that specific type SINCE accept,
	# not lifetime -- run_kills_by_name never resets mid-run. ---
	var cull_index := templates.find("cull_the_herd")
	if cull_index == -1:
		# Force one into being for a deterministic test of this template.
		main.quest_slots[0] = main._build_quest("cull_the_herd")
		cull_index = 0
	var cull_slot: Dictionary = main.quest_slots[cull_index]
	main.run_kills_by_name[cull_slot.target_name] = 3
	print("progress before accepting is 0 regardless of prior kills: %d (expected 0)" % [
		main._quest_progress(main.quest_slots[cull_index]) if main.quest_slots[cull_index].accepted else 0
	])
	main.accept_quest(cull_index)
	print("accepting captures a baseline at the CURRENT kill count, not zero: baseline=%d (expected 3)" % [main.quest_slots[cull_index].baseline])
	main.run_kills_by_name[cull_slot.target_name] = 3 + cull_slot.target_amount
	print("progress only counts kills after accepting: %d (expected %d)" % [
		main._quest_progress(main.quest_slots[cull_index]), cull_slot.target_amount
	])
	print("...and is now claimable: %s (expected true)" % [main.is_quest_complete(cull_index)])
	var coins_before: int = player.coins
	main.claim_quest(cull_index)
	print("claiming grants the reward and rerolls the slot: coins_gained=%s (expected true), new_slot_unaccepted=%s (expected true)" % [
		player.coins > coins_before, not main.quest_slots[cull_index].accepted
	])

	# --- Monster Slayer: progress = total_kills since accept. ---
	main.quest_slots[1] = main._build_quest("monster_slayer")
	main.total_kills = 50
	main.accept_quest(1)
	print("Monster Slayer baselines off total_kills at accept time: baseline=%d (expected 50)" % [main.quest_slots[1].baseline])
	main.total_kills = 50 + main.quest_slots[1].target_amount
	print("...and completes once enough kills land after that: %s (expected true)" % [main.is_quest_complete(1)])

	# --- Treasure Hunter: a live threshold, no baseline needed. ---
	main.quest_slots[2] = main._build_quest("treasure_hunter")
	player.coins = 0
	main.accept_quest(2)
	print("Treasure Hunter isn't complete while under the threshold: %s (expected false)" % [main.is_quest_complete(2)])
	player.coins = main.quest_slots[2].target_amount
	print("...and completes the instant the balance reaches it, no baseline needed: %s (expected true)" % [main.is_quest_complete(2)])
	# Spending back down un-completes it -- it's a live check, not a one-time trigger.
	player.coins = 0
	print("...and drops back out of completion if the balance drops again: %s (expected false)" % [main.is_quest_complete(2)])

	quit()
