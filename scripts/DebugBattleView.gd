extends "res://scripts/DebugViewBase.gd"

# BATTLE: start a fight against a chosen enemy (any count, danger tier, elite or not) or a ready-made squad; and, in a fight, win or
# lose it at once, heal everyone, refill your turn, kill or hurt single enemies, and put any status on (or take it off) you, an
# ally or an enemy.

const SandboxScript := preload("res://scripts/Sandbox.gd")

const LEFT_W := 540.0

var bs: Dictionary = {}          # this tab's remembered state (menu.state.battle)

func build() -> void:
	clear()
	if not menu.state.has("battle"):
		menu.state["battle"] = {"target": "hero", "status": "poison", "turns": 3}
	bs = menu.state.battle
	if not menu.state.has("enemy_cfg"):
		menu.state["enemy_cfg"] = {"enemy": "Goblin", "enemy_search": "", "count": 1, "tier": 1, "elite": false, "power": 1.0, "level": 0}
	_left_column()
	_right_column()

# --- starting a battle -------------------------------------------------------------------------------------------------------------

func _left_column() -> void:
	var k := DebugKitScript
	var cfg: Dictionary = menu.state.enemy_cfg
	var scroll: ScrollContainer = k.scroll(Vector2(LEFT_W, size.y))
	add_child(scroll)
	var col: VBoxContainer = k.vbox(scroll, 4)
	k.section(col, "Start a battle")
	enemy_picker(col, cfg)
	var set_count := func(v):
		cfg["count"] = v
		return DebugActionsScript.ok("Count: %d." % v)
	num(col, "How many", int(cfg.count), set_count, {"min": 1, "max": 12, "steps": [1], "label_w": 150})
	var set_tier := func(v):
		cfg["tier"] = v
		return DebugActionsScript.ok("Danger tier %d: enemies get x%s HP and damage." % [v, DebugActionsScript._fmt(DebugWorldScript.tier_power(v))])
	num(col, "Danger tier", int(cfg.tier), set_tier, {"min": 1, "max": 8, "steps": [1], "label_w": 150},
		"1 (the plains) to 8 (the Voidlands): each tier multiplies enemy HP and damage, on top of your level and the difficulty (x%s at tier %d)." % [DebugActionsScript._fmt(DebugWorldScript.tier_power(int(cfg.tier))), int(cfg.tier)])
	enemy_level_row(col, cfg)
	var set_elite := func(v):
		cfg["elite"] = v
		return DebugActionsScript.ok("Elite: %s." % ("on" if v else "off"))
	switch_row(col, "Elite", bool(cfg.elite), set_elite)
	var power_row: HBoxContainer = k.row(col, "Extra strength", 150.0, "Multiplies the enemy's HP and damage once more, after everything else.")
	k.choice_row(power_row, [["0.5", "x0.5"], ["1", "x1"], ["2", "x2"], ["5", "x5"], ["10", "x10"]], DebugActionsScript._fmt(float(cfg.power)), func(id):
		cfg["power"] = float(id)
		refresh())
	var go := k.flow(col)
	var start: PixelButton = k.button("Start battle", func():
		act(DebugBattleScript.start_battle(main, [{"name": str(cfg.enemy), "count": int(cfg.count)}], int(cfg.tier), bool(cfg.elite), float(cfg.power), int(cfg.get("level", 0)))), true)
	k.set_enabled(start, not bool(main.in_battle))
	go.add_child(start)
	k.section(col, "Ready-made squads")
	var presets := k.flow(col)
	for preset in SandboxScript.SQUAD_PRESETS:
		var spec: Array = []
		var counts := {}
		for n in preset[1]:
			counts[n] = int(counts.get(n, 0)) + 1
		for n in counts:
			spec.append({"name": str(n), "count": int(counts[n])})
		var b: PixelButton = k.button(str(preset[0]), func(): act(DebugBattleScript.start_battle(main, spec, int(cfg.tier), bool(cfg.elite), float(cfg.power), int(cfg.get("level", 0)))))
		k.set_enabled(b, not bool(main.in_battle))
		presets.add_child(b)
	k.section(col, "Try an attack style")
	k.note(col, "Plays the popup each weapon uses, on its own (nothing is attacked): the menu closes and the popup opens at the bottom right.")
	var styles := k.flow(col)
	for style in DebugBattleScript.ATTACK_STYLES:
		var style_id: String = str(style[0])
		styles.add_child(k.button(str(style[1]), func(): act(DebugBattleScript.play_attack_style(main, style_id)), false, "", str(style[2])))
	k.spacer(col, 12)

# --- while it is on -----------------------------------------------------------------------------------------------------------------

func _right_column() -> void:
	var k := DebugKitScript
	var x := LEFT_W + 12.0
	var panel := PixelKit.panel("panel_steel", 8, 4)
	panel.position = Vector2(x, 0)
	panel.size = Vector2(size.x - x, size.y)
	panel.custom_minimum_size = panel.size
	add_child(panel)
	var scroll: ScrollContainer = k.scroll(Vector2.ZERO)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var col: VBoxContainer = k.vbox(scroll, 4)
	var fighting: bool = bool(main.in_battle)
	k.section(col, "In the battle")
	if not fighting:
		k.note(col, "There is no battle going. Start one on the left, or walk into an enemy; then these work.")
	else:
		var why: String = DebugBattleScript.why_cannot_finish(main)
		if why != "":
			k.note(col, why, PixelKit.GOLD3)
	var ends := k.flow(col)
	var win: PixelButton = k.button("Win now", func(): act(DebugBattleScript.win_now(main)), true, "", "Every enemy falls (XP and drops as if you had killed them) and the battle is won.")
	var lose: PixelButton = k.button("Lose now", func(): menu.confirm("End the run? You fall at once and the game-over screen follows.", func(): act(DebugBattleScript.lose_now(main))), false, "", "You fall: the game-over screen.")
	var heal: PixelButton = k.button("Heal everyone", func(): act(DebugBattleScript.heal_everyone(main)))
	var refill: PixelButton = k.button("Refill my turn", func(): act(DebugBattleScript.refill_turn(main)), false, "", "Full movement and stamina again.")
	var end_turn: PixelButton = k.button("End my turn", func(): act(DebugBattleScript.end_my_turn(main)), false, "", "Passes your turn, as if you had pressed End Turn.")
	for b in [win, lose, refill, end_turn]:
		k.set_enabled(b, fighting)
	for b in [win, lose, heal, refill, end_turn]:
		ends.add_child(b)
	k.section(col, "Fight cheats")
	switch_row(col, "Always crit", player().debug_always_crit, func(v): return DebugBattleScript.set_always_crit(main, v), "Every hit you or your party lands is a critical hit.")
	switch_row(col, "Enemies stand still", player().debug_enemies_pass, func(v): return DebugBattleScript.set_enemies_pass(main, v), "Enemies skip their turns (their statuses still tick).")
	switch_row(col, "Never miss", DebugBattleScript.never_miss_on(main), func(v): return DebugBattleScript.set_never_miss(main, v), "Your attacks and your party's always land. Off puts the real miss chances back.")
	if not fighting:
		return
	k.section(col, "Statuses")
	var targets: Array = DebugBattleScript.targets(main)
	var target_id := str(bs.target)
	var found := false
	for t in targets:
		if str(t.id) == target_id:
			found = true
	if not found:
		target_id = "hero"
		bs["target"] = "hero"
	var target: Dictionary = {}
	for t in targets:
		if str(t.id) == target_id:
			target = t
	var target_options: Array = []
	for t in targets:
		target_options.append([str(t.id), str(t.label)])
	var who := k.row(col, "Who", 90.0)
	k.choice_row(who, target_options, target_id, func(id):
		bs["target"] = str(id)
		refresh())
	var kind := str(target.get("kind", "hero"))
	var status_ids: Array = DebugBattleScript.statuses_for(kind)
	if not status_ids.has(str(bs.status)):
		bs["status"] = str(status_ids[0])
	var status_options: Array = []
	for sid in status_ids:
		status_options.append([str(sid), DebugBattleScript.status_name(str(sid))])
	var what := k.row(col, "Status", 90.0)
	k.choice_row(what, status_options, str(bs.status), func(id):
		bs["status"] = str(id)
		refresh())
	k.note(col, DebugBattleScript.status_desc(str(bs.status)))
	var set_turns := func(v):
		bs["turns"] = v
		return DebugActionsScript.ok("Turns: %d." % v)
	num(col, "Turns", int(bs.turns), set_turns, {"min": 1, "max": 20, "steps": [1], "label_w": 90})
	var apply_row := k.flow(col)
	apply_row.add_child(k.button("Put it on", func(): act(DebugBattleScript.set_status(main, target_id, str(bs.status), int(bs.turns))), true))
	apply_row.add_child(k.button("Take it off", func(): act(DebugBattleScript.set_status(main, target_id, str(bs.status), 0, true))))
	apply_row.add_child(k.button("Clear all", func(): act(DebugBattleScript.clear_statuses(main, target_id))))
	var has: Array = DebugBattleScript.status_list(main, target_id)
	if not has.is_empty():
		var names: Array = has.map(func(e): return "%s%s" % [str(e.name), (" (%s)" % str(e.detail)) if str(e.detail) != "" else ""])
		k.note(col, "Now: %s" % ", ".join(names), PixelKit.CREAM)
	k.section(col, "Your turn")
	num(col, "Tiles left to walk", int(main.battle_player_moves_left), func(v): return DebugBattleScript.set_moves_left(main, v), {"min": 0, "max": 30, "steps": [1], "label_w": 190})
	num(col, "Kills towards Berserk", int(player().berserk_kills), func(v): return DebugBattleScript.set_berserk_kills(main, v), {"min": 0, "max": 50, "steps": [1], "label_w": 190},
		"The kills counted towards your next Berserk (it starts on the 5th).")
	num(col, "Momentum stacks", int(main.battle_momentum_stacks), func(v): return DebugBattleScript.set_momentum(main, v), {"min": 0, "max": 50, "steps": [1], "label_w": 190})
	# everyone's HP: type a number and press Enter; Edit opens everything about that unit in the Inspector
	k.section(col, "Everyone's HP")
	_unit_line(col, "You  %d / %d HP" % [int(player().health), int(player().max_health)], "hero", int(player().health), "player", "")
	for ai in main.battle_allies.size():
		var ally: Dictionary = main.battle_allies[ai]
		_unit_line(col, "%s  %d / %d HP" % [str(ally.get("name", "Ally")), int(ally.hp), int(ally.max_hp)], "ally:%d" % ai, int(ally.hp), "ally:%d" % ai, "Down it", func(): act(DebugBattleScript.down_ally(main, ai)))
	for di in main.battle_downed_allies.size():
		var downed: Dictionary = main.battle_downed_allies[di]
		var dline := k.hbox(col, 6)
		var dlabel := PixelKit.label("%s  (down)" % str(downed.get("name", "Ally")), "body", PixelKit.DIM)
		dlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dline.add_child(dlabel)
		dline.add_child(k.button("Stand up", func(): act(DebugBattleScript.revive_ally(main, di))))
	for i in main.battle_units.size():
		var u: Dictionary = main.battle_units[i]
		_unit_line(col, "%s  %d / %d HP" % [str(u.name), int(u.hp), int(u.max_hp)], "enemy:%d" % i, int(u.hp), "enemy:%d" % i, "Kill it", func(): act(DebugBattleScript.kill_enemy(main, i)))
	# more of anything
	var cfg: Dictionary = menu.state.enemy_cfg
	k.section(col, "Add to the fight")
	k.note(col, "The enemy, count, danger tier, level and strength on the left apply.")
	var add := k.flow(col)
	add.add_child(k.button("Add %d x %s" % [int(cfg.count), str(cfg.enemy)], func(): act(DebugBattleScript.add_enemy(main, str(cfg.enemy), int(cfg.count), int(cfg.tier), bool(cfg.elite), float(cfg.power), int(cfg.get("level", 0)))), true))
	k.note(col, "A new party member (the party's size limit is raised if it must be):")
	var allies_row := k.flow(col)
	for member_kind in DebugActionsScript.member_kinds():
		var kind_id: String = str(member_kind.kind)
		allies_row.add_child(k.button(str(member_kind.name), func(): act(DebugBattleScript.add_ally(main, kind_id))))
	_move_and_build(col, targets, target_id)
	k.spacer(col, 12)

# One row for a unit: what it is, a box to type its HP into, an optional second action (Kill it / Down it) and Edit (the Inspector).
func _unit_line(col: VBoxContainer, text: String, hp_target: String, hp: int, inspect_id: String, action_text: String, action: Callable = Callable()) -> void:
	var k := DebugKitScript
	var line := k.hbox(col, 6)
	var label := PixelKit.label(text, "body", PixelKit.CREAM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	line.add_child(label)
	var field := k.line_edit(str(hp), 70, "HP")
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.tooltip_text = "Type its HP and press Enter (1 up to its max)."
	field.text_submitted.connect(func(t): act(DebugBattleScript.set_unit_hp(main, hp_target, t.to_int())))
	line.add_child(field)
	if action.is_valid():
		line.add_child(k.button(action_text, action))
	line.add_child(k.button("Edit", func(): menu.open_inspector(inspect_id), false, "", "Opens every variable of it in the Console tab's Inspector."))

# Put a unit on a tile, and change the ground under the fight.
func _move_and_build(col: VBoxContainer, targets: Array, target_id: String) -> void:
	var k := DebugKitScript
	if not bs.has("tx"):
		bs["tx"] = 0
		bs["ty"] = 0
		bs["terrain"] = "rock"
	k.section(col, "Move and build")
	var single: bool = target_id == "hero" or target_id.begins_with("ally:") or target_id.begins_with("enemy:")
	var who := "the one picked under Statuses (%s)" % target_id if single else "nobody: pick one unit under Statuses"
	k.note(col, "Grid %d x %d, tiles counted from 0. Moves %s." % [main.BATTLE_GRID_W, main.BATTLE_GRID_H, who])
	var set_tx := func(v):
		bs["tx"] = v
		return DebugActionsScript.ok("x = %d." % v)
	var set_ty := func(v):
		bs["ty"] = v
		return DebugActionsScript.ok("y = %d." % v)
	num(col, "Tile x", int(bs.tx), set_tx, {"min": 0, "max": main.BATTLE_GRID_W - 1, "steps": [1], "label_w": 190})
	num(col, "Tile y", int(bs.ty), set_ty, {"min": 0, "max": main.BATTLE_GRID_H - 1, "steps": [1], "label_w": 190})
	var move: PixelButton = k.button("Move them to (%d, %d)" % [int(bs.tx), int(bs.ty)], func(): act(DebugBattleScript.move_unit(main, target_id, int(bs.tx), int(bs.ty))), true)
	k.set_enabled(move, single)
	var move_row := k.flow(col)
	move_row.add_child(move)
	var terrain_options: Array = []
	for t in DebugBattleScript.terrain_types(main):
		terrain_options.append([str(t), str(t).capitalize().replace("_", " ")])
	var terrain_row := k.row(col, "Ground", 90.0)
	k.choice_row(terrain_row, terrain_options, str(bs.terrain), func(id):
		bs["terrain"] = str(id)
		refresh())
	var ground := k.flow(col)
	ground.add_child(k.button("Place it at (%d, %d)" % [int(bs.tx), int(bs.ty)], func(): act(DebugBattleScript.set_terrain(main, int(bs.tx), int(bs.ty), str(bs.terrain))), true))
	ground.add_child(k.button("Clear that tile", func(): act(DebugBattleScript.clear_terrain(main, int(bs.tx), int(bs.ty)))))
	ground.add_child(k.button("Clear all ground", func(): act(DebugBattleScript.clear_all_terrain(main))))
