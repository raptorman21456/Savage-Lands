extends "res://scripts/DebugViewBase.gd"

# PROGRESS: the Church's upgrades (grant, remove, max all, reset -- read from SaveData.UPGRADES, never by id), the lifetime flags (tutorial,
# game beaten, Druid freed...), the Wizard's Tower's spell levels, the Dojo's lessons, and the Beastiary.

const SpellUpgradesScript := preload("res://scripts/SpellUpgrades.gd")

var _church_list: VBoxContainer = null

func build() -> void:
	clear()
	var k := DebugKitScript
	var col: VBoxContainer = column()
	var essence: int = DebugActionsScript.essence(main)

	k.section(col, "Church upgrades  (they last for good, like the real thing)")
	num(col, "Banked Essence", essence, func(v): return DebugActionsScript.set_essence(main, v), {"min": 0, "max": 99999999, "steps": [10, 100], "width": 130})
	var bulk := k.flow(col)
	bulk.add_child(k.button("Max all", func(): act(DebugProgressScript.max_all_upgrades(main)), false, "", "Every upgrade to its highest level (those without a ceiling to %d)." % DebugProgressScript.UNLIMITED_LEVEL))
	bulk.add_child(k.button("Reset all", func(): menu.confirm("Take every Church upgrade away? (The Essence you have stays.)", func(): act(DebugProgressScript.reset_upgrades(main)))))
	var rows: Array = DebugProgressScript.upgrade_rows()
	var owned_levels := 0
	for r in rows:
		owned_levels += int(r.level)
	k.note(col, "%d upgrades, %d levels owned. Grants skip the prerequisites. A grant is applied to this run at once, like a purchase." % [rows.size(), owned_levels])
	var search_text := str(menu.state.get("church_search", ""))
	_church_list = k.vbox(null, 2)
	var bar := k.hbox(col, 10)
	bar.add_child(k.search_field(search_text, func(t):
		menu.state["church_search"] = t
		_fill_church(rows)
	, "Search upgrades"))
	col.add_child(_church_list)
	_fill_church(rows)

	k.section(col, "Lifetime flags  (kept across every save slot)")
	for f in DebugProgressScript.lifetime_flags():
		var key: String = str(f.key)
		var on: bool = bool(f.on)
		switch_row(col, str(f.label), on, func(v):
			if key == "tutorial_completed_ever":
				return DebugProgressScript.set_tutorial_done(main, v)
			return DebugProgressScript.set_lifetime_flag(key, v))
	var flags_row := k.flow(col)
	flags_row.add_child(k.button("Show the one-time pop-ups again", func(): act(DebugProgressScript.reset_seen_unlocks())))
	var numbers: Array = DebugProgressScript.lifetime_numbers()
	if not numbers.is_empty():
		var parts: Array = numbers.map(func(n): return "%s %d" % [str(n[0]), int(n[1])])
		k.note(col, "  ·  ".join(parts))

	k.section(col, "Spell upgrades  (the Wizard's Tower; they last for this run)")
	var spell_all := k.flow(col)
	for level in range(SpellUpgradesScript.MAX_LEVEL + 1):
		var lv: int = level
		spell_all.add_child(k.button("All %s" % ["plain", "+", "EX"][lv], func(): act(DebugProgressScript.set_all_spells(main, lv))))
	if player().party.is_empty():
		k.note(col, "Recruit a party member first: a spell upgrade belongs to its caster.")
	for member in player().party:
		var caster = member
		for entry in main.member_special_pool(caster):
			var spell_id: String = str(entry.special.get("id", ""))
			if not SpellUpgradesScript.has(spell_id):
				continue
			var row: HBoxContainer = k.row(col, "%s: %s" % [str(caster.name), str(SpellUpgradesScript.spell(spell_id).name)], 330.0, SpellUpgradesScript.level_text(spell_id, int(player().spell_level_of(caster, spell_id))))
			var options: Array = []
			for level in range(SpellUpgradesScript.MAX_LEVEL + 1):
				options.append([level, ["plain", "+", "EX"][level]])
			k.choice_row(row, options, int(player().spell_level_of(caster, spell_id)), func(id): act(DebugProgressScript.set_spell_level(main, caster, spell_id, int(id))))

	k.section(col, "Dojo")
	var dojo := k.flow(col)
	dojo.add_child(k.button("Learn every weapon special", func(): act(DebugProgressScript.learn_all_specials(main))))
	dojo.add_child(k.button("Forget them all", func(): act(DebugProgressScript.forget_all_specials(main))))
	readout(col, "Learned", "%d" % player().learned_specials.size(), PixelKit.DIM)

	k.section(col, "Beastiary")
	var names: Array = DebugProgressScript.beastiary_names()
	readout(col, "Creatures seen", "%d of %d" % [DebugProgressScript.beastiary_seen_count(), names.size()], PixelKit.DIM)
	var beast := k.flow(col)
	beast.add_child(k.button("Reveal all", func(): act(DebugProgressScript.reveal_beastiary())))
	beast.add_child(k.button("Hide all", func(): act(DebugProgressScript.hide_beastiary())))
	k.spacer(col, 12)

# The upgrade rows (filtered by the search box), refilled in place so typing in the box keeps the keyboard.
func _fill_church(rows: Array) -> void:
	for c in _church_list.get_children():
		_church_list.remove_child(c)
		c.queue_free()
	var needle := str(menu.state.get("church_search", "")).to_lower()
	var k := DebugKitScript
	for r in rows:
		if needle != "" and not str(r.name).to_lower().contains(needle):
			continue
		var id: String = str(r.id)
		var row := k.hbox(_church_list, 8)
		row.custom_minimum_size = Vector2(0, 44)
		var name_label := PixelKit.label(str(r.name), "body", PixelKit.CREAM if bool(r.unlocked) else PixelKit.DIM)
		name_label.custom_minimum_size = Vector2(250, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.tooltip_text = str(r.description)
		row.add_child(name_label)
		var level_text := "%d / %d" % [int(r.level), int(r.max)] if bool(r.capped) else "%d" % int(r.level)
		var level_label := PixelKit.label(level_text, "body", PixelKit.GOLD3 if int(r.level) > 0 else PixelKit.DIM)
		level_label.custom_minimum_size = Vector2(80, 0)
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(level_label)
		var minus: PixelButton = k.button("−", func(): act(DebugProgressScript.remove_upgrade(main, id)))
		k.set_enabled(minus, int(r.level) > 0)
		row.add_child(minus)
		var plus: PixelButton = k.button("+", func(): act(DebugProgressScript.grant_upgrade(main, id)))
		k.set_enabled(plus, int(r.level) < int(r.max) or not bool(r.capped))
		row.add_child(plus)
		if not bool(r.unlocked):
			var lock := PixelKit.label("prerequisite not met", "body", PixelKit.DIM)
			lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(lock)
