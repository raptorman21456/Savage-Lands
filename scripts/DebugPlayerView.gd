extends "res://scripts/DebugViewBase.gd"

# PLAYER: level and XP, health and stamina, every stat, coins / shards / banked Essence, and the cheats (god mode, infinite stamina,
# one-hit kills, walking speed). Everything goes through DebugActions.

const SPEEDS := [["0.5", "x0.5"], ["1", "x1"], ["1.5", "x1.5"], ["2", "x2"], ["3", "x3"], ["5", "x5"]]

func build() -> void:
	clear()
	var p = player()
	var col: VBoxContainer = column()
	var k := DebugKitScript

	k.section(col, "Level and XP")
	num(col, "Level", p.level, func(v): return DebugActionsScript.set_level(main, v), {"min": 1, "max": 99, "steps": [1, 5]},
		"Sets the level the way levelling does (+1 to every stat per level). Going DOWN starts your stats over, so stat picks are lost.")
	var xp_row: HBoxContainer = k.row(col, "Give XP", 230.0, "Goes through the normal XP gain, so it can level you up (and the level-up picker opens when you close this menu).")
	for amount in [10, 100, 1000]:
		xp_row.add_child(k.button("+%d" % amount, func(): act(DebugActionsScript.give_xp(main, amount))))
	xp_row.add_child(k.button("To next level", func(): act(DebugActionsScript.give_xp(main, maxi(1, p.xp_to_next - p.xp)))))
	readout(col, "XP", "%d / %d%s" % [p.xp, p.xp_to_next, "   (top level)" if p.level >= 99 else ""], PixelKit.DIM)

	k.section(col, "Health and stamina")
	num(col, "HP  (max %d)" % p.max_health, p.health, func(v): return DebugActionsScript.set_health(main, v), {"min": 1, "max": p.max_health, "steps": [1, 10]})
	num(col, "Stamina  (max %d)" % p.max_stamina, p.stamina, func(v): return DebugActionsScript.set_stamina(main, v), {"min": 0, "max": p.max_stamina, "steps": [1, 10]})
	var hp_row: HBoxContainer = k.row(col, "Max HP bonus", 230.0, "Adds to (or takes from) your max HP the game's own way: the Hardened bonus, which also heals by the same amount.")
	for amount in [-10, -1, 1, 10, 50]:
		hp_row.add_child(k.button(("−%d" % absi(amount)) if amount < 0 else ("+%d" % amount), func(): act(DebugActionsScript.add_max_hp(main, amount))))
	var heal_row: HBoxContainer = k.row(col, "", 230.0)
	heal_row.add_child(k.button("Heal fully", func(): act(DebugActionsScript.heal_hero(main))))

	k.section(col, "Stats")
	for s in DebugActionsScript.stat_rows(main):
		var label: String = "%s (%s)" % [s.name, s.abbr]
		if s.locked:
			label += " - locked"
		var tip: String = "%s%s" % [load("res://scripts/UIIcons.gd").stat_tooltip(s.id), "  (Locked: the Church has not unlocked it yet. You can still set it here.)" if s.locked else ""]
		if s.id == "agility":
			# shown as the speed rating the rest of the game uses (the real number is pixels a second, 180 to start)
			num(col, label, DebugActionsScript.agility_rating(main), func(v): return DebugActionsScript.set_agility_rating(main, v), {"min": 1, "max": 99, "steps": [1, 5]},
				tip + "  Shown as the speed rating (5 to start); the walking speed behind it is %d px/s." % int(p.stat_agility))
		else:
			num(col, label, int(p.get("stat_" + s.id)), func(v): return DebugActionsScript.set_stat(main, s.id, v), {"min": 0, "max": 9999, "steps": [1, 10]}, tip)

	k.section(col, "Money")
	num(col, "Coins", p.coins, func(v): return DebugActionsScript.set_coins(main, v), {"min": 0, "max": 99999999, "steps": [10, 100], "width": 130})
	num(col, "Runic shards", p.runic_shards, func(v): return DebugActionsScript.set_shards(main, v), {"min": 0, "max": 999999, "steps": [1, 10]})
	num(col, "Banked Essence", DebugActionsScript.essence(main), func(v): return DebugActionsScript.set_essence(main, v), {"min": 0, "max": 99999999, "steps": [10, 100], "width": 130},
		"The Essence the Church spends. It lives in the save slot, not in this run.")

	k.section(col, "Cheats")
	switch_row(col, "God mode", p.debug_god_mode, func(v): return DebugActionsScript.set_god_mode(main, v), "Nothing can hurt you: no hit, poison, bleed or fall lands.")
	switch_row(col, "Infinite stamina", p.debug_infinite_stamina, func(v): return DebugActionsScript.set_infinite_stamina(main, v), "Every cost is free and the bar stays full.")
	switch_row(col, "One-hit kills", DebugActionsScript.one_hit_kills_on(main), func(v): return DebugActionsScript.set_one_hit_kills(main, v), "Any hit that lands (yours or your party's) destroys its target.")
	var speed_row: HBoxContainer = k.row(col, "Walking speed", 230.0, "How fast you walk on the map.")
	k.choice_row(speed_row, SPEEDS.map(func(s): return [s[0], s[1]]), DebugActionsScript._fmt(p.debug_speed_mult), func(id): act(DebugActionsScript.set_speed_mult(main, float(id))))
	k.spacer(col, 12)
