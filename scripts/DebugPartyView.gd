extends "res://scripts/DebugViewBase.gd"

# PARTY: recruit any kind of member (the party limit can be ignored), then for the one picked: set its level, grant or spend bonus picks,
# hand it a weapon / armour / shield / talismans (any, even ones you do not own yet), heal or revive it, or send it away.

const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const DebugWeaponPickScript := preload("res://scripts/DebugWeaponPick.gd")

const LEFT_W := 350.0

var ps: Dictionary = {}          # this tab's remembered state (menu.state.party)

func build() -> void:
	clear()
	if not menu.state.has("party"):
		menu.state["party"] = {"selected": -1, "override": false, "pick": "", "weapon": {"base": "dagger", "tier": "Fine", "material": "steel"}}
	ps = menu.state.party
	var p = player()
	var members: Array = p.party
	if DebugActionsScript.find_member(main, int(ps.selected)) == null:
		ps["selected"] = int(members[0].id) if not members.is_empty() else -1
		ps["pick"] = ""
	_left_column()
	_right_column()

# --- the roster and the recruiting ---------------------------------------------------------------------------------------------

func _left_column() -> void:
	var k := DebugKitScript
	var p = player()
	var scroll: ScrollContainer = k.scroll(Vector2(LEFT_W, size.y))
	add_child(scroll)
	var col: VBoxContainer = k.vbox(scroll, 4)
	k.section(col, "Party  (%d of %d places)" % [p.party.size() + p.party_members.size(), p.party_capacity()])
	if p.party.is_empty() and p.party_members.is_empty():
		k.note(col, "Nobody yet. Recruit below.")
	for m in p.party:
		var member_id: int = int(m.id)
		var label: String = "%s%s" % [m.name, ("  Lv %d" % m.level) if m.levels() else ""]
		col.add_child(k.button(label, func():
			ps["selected"] = member_id
			ps["pick"] = ""
			refresh()
		, member_id == int(ps.selected)))
	for i in p.party_members.size():
		var idx: int = i
		var line := k.hbox(col, 6)
		var tag := PixelKit.label("%s (flat companion)" % str(p.party_members[i].get("name", "?")), "body", PixelKit.DIM)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(tag)
		line.add_child(k.button("Remove", func(): act(DebugActionsScript.remove_mercenary(main, idx))))
	k.section(col, "Recruit")
	var rule_row: HBoxContainer = k.row(col, "Ignore the party limit", 220.0, "Off: a full party refuses. On: the party's size limit is raised just enough to fit the new member.")
	var sw: PixelButton = k.button("On" if bool(ps.override) else "Off", func():
		ps["override"] = not bool(ps.override)
		refresh()
	, bool(ps.override))
	sw.custom_minimum_size = Vector2(80, 0)
	rule_row.add_child(sw)
	var kinds := k.flow(col)
	for kind in DebugActionsScript.member_kinds():
		var kind_id: String = str(kind.kind)
		kinds.add_child(k.button(str(kind.name), func(): act(DebugActionsScript.recruit(main, kind_id, bool(ps.override))), false, "", PartyRulesScript.description_for(kind_id)))
	k.spacer(col, 6)
	var all := k.flow(col)
	all.add_child(k.button("Heal / revive everyone", func(): act(DebugActionsScript.heal_party(main))))
	all.add_child(k.button("Dismiss everyone", func(): menu.confirm("Send the whole party away?", func(): act(DebugActionsScript.dismiss_all(main)))))
	k.spacer(col, 12)

# --- the one picked --------------------------------------------------------------------------------------------------------------

func _right_column() -> void:
	var k := DebugKitScript
	var panel := PixelKit.panel("panel_steel", 8, 4)
	panel.position = Vector2(LEFT_W + 12, 0)
	panel.size = Vector2(size.x - LEFT_W - 12, size.y)
	panel.custom_minimum_size = panel.size
	add_child(panel)
	var scroll: ScrollContainer = k.scroll(Vector2.ZERO)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var col: VBoxContainer = k.vbox(scroll, 4)
	var m = DebugActionsScript.find_member(main, int(ps.selected))
	if m == null:
		k.note(col, "Pick a member on the left, or recruit one.")
		return
	if str(ps.pick) != "" and m.can_carry_gear():
		_picker(col, m)
		return
	_sheet(col, m)

func _sheet(col: VBoxContainer, m) -> void:
	var k := DebugKitScript
	var id: int = int(m.id)
	var head := PixelKit.label("%s  ·  %s" % [m.name, "Lv %d" % m.level if m.levels() else "never levels"], "head", PixelKit.GOLD3)
	col.add_child(head)
	k.note(col, PartyRulesScript.description_for(str(m.kind)))
	if m.levels():
		k.section(col, "Level")
		num(col, "Level", m.level, func(v): return DebugActionsScript.set_member_level(main, id, v), {"min": 1, "max": 99, "steps": [1, 5], "label_w": 150})
		num(col, "Bonus picks to spend", m.picks, func(v): return DebugActionsScript.grant_picks(main, id, int(v) - m.picks), {"min": 0, "max": 999, "steps": [1, 5], "label_w": 150})
		if m.picks > 0:
			var pick_row: HBoxContainer = k.row(col, "Spend a pick on", 150.0)
			var stats := k.flow(pick_row)
			for stat in m.pickable_stats():
				var stat_name: String = str(stat)
				stats.add_child(k.button("HP" if stat_name == "hp" else stat_name.capitalize(), func(): act(DebugActionsScript.spend_pick(main, id, stat_name))))
	k.section(col, "Right now")
	var facts: Array = ["HP %d" % m.max_hp(), "Attack %s" % DebugActionsScript._fmt(snappedf(m.attack(), 0.1)), "Defense %d" % int(round(m.defense_pct())), "Fortitude %d" % int(round(m.fortitude())),
		"Speed %s  (%d tiles)" % [DebugActionsScript._fmt(snappedf(m.speed(), 0.1)), m.move_tiles()]]
	if m.is_caster():
		facts.append("Magic %s" % DebugActionsScript._fmt(snappedf(m.magic(), 0.1)))
	k.note(col, "   ·   ".join(facts), PixelKit.CREAM)
	if m.is_wolf():
		k.note(col, "Loyalty: %d battles left.  Faints: %d." % [m.battles_left, m.faints])
	if m.can_carry_gear():
		k.section(col, "Gear")
		_gear_row(col, m, "Weapon", "weapon", _name_of_weapon(m.weapon_id()), m.weapon_id() != "")
		_gear_row(col, m, "Armour", "armor", str(ArmorScript.find(m.armor_id()).get("name", "")) if m.armor_id() != "" else "", m.armor_id() != "")
		_gear_row(col, m, "Shield", "shield", str(ShieldsScript.SHIELDS.get(m.shield_id(), {}).get("name", "")) if m.shield_id() != "" else "", m.shield_id() != "")
		var worn: Array = m.talisman_ids().map(func(t): return str(TalismansScript.get_talisman(str(t)).get("name", t)))
		var tal_row: HBoxContainer = k.row(col, "Talismans (%d of %d)" % [worn.size(), m.talisman_slot_count()], 220.0)
		var tal_text := PixelKit.label(", ".join(worn) if not worn.is_empty() else "none", "body", PixelKit.CREAM if not worn.is_empty() else PixelKit.DIM)
		tal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tal_row.add_child(tal_text)
		tal_row.add_child(k.button("Change", func(): _open_picker("talisman")))
		var none: PixelButton = k.button("Take all off", func(): act(DebugActionsScript.unequip_member(main, id, "talisman")))
		k.set_enabled(none, not worn.is_empty())
		tal_row.add_child(none)
	k.section(col, "Other")
	var other := k.flow(col)
	other.add_child(k.button("Heal / revive", func(): act(DebugActionsScript.heal_party(main)), false, "", "In a battle: full HP and resources, and the downed stand up. Out of one: resets a wolf's faints and loyalty."))
	other.add_child(k.button("Dismiss %s" % m.name, func(): menu.confirm("Send %s away?" % m.name, func(): act(DebugActionsScript.dismiss(main, id)))))
	k.spacer(col, 12)

func _name_of_weapon(weapon_id: String) -> String:
	if weapon_id == "":
		return ""
	var v: Dictionary = WeaponsScript.get_owned_variant(weapon_id)
	return DebugActionsScript._weapon_label(v) if not v.is_empty() else weapon_id

func _gear_row(col: VBoxContainer, m, label_text: String, slot: String, current: String, has: bool) -> void:
	var k := DebugKitScript
	var id: int = int(m.id)
	var row: HBoxContainer = k.row(col, label_text, 220.0)
	var text := PixelKit.label(current if has else "none", "body", PixelKit.CREAM if has else PixelKit.DIM)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	row.add_child(k.button("Change", func(): _open_picker(slot)))
	var off: PixelButton = k.button("Take off", func(): act(DebugActionsScript.unequip_member(main, id, slot)))
	k.set_enabled(off, has)
	row.add_child(off)

func _open_picker(slot: String) -> void:
	ps["pick"] = slot
	refresh()

# --- the gear pickers ---------------------------------------------------------------------------------------------------------------

func _picker(col: VBoxContainer, m) -> void:
	var k := DebugKitScript
	var id: int = int(m.id)
	var slot: String = str(ps.pick)
	var top := k.hbox(col, 12)
	top.add_child(k.button("Back", func():
		ps["pick"] = ""
		refresh()
	))
	var title := PixelKit.label("%s: %s" % [m.name, {"weapon": "weapon", "armor": "armour", "shield": "shield", "talisman": "talismans"}[slot]], "head", PixelKit.GOLD3)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	k.note(col, "Any item can be given here: you are handed it if you do not own it, and it is taken from whoever had it.")
	match slot:
		"weapon":
			var variant: Dictionary = DebugWeaponPickScript.build(col, ps.weapon, refresh)
			if not variant.is_empty():
				var vid := str(variant.id)
				var only: String = str(m.rules().get("weapon_only", ""))
				var base_id := str(WeaponsScript.get_base_type(variant).get("id", ""))
				var blocked: bool = only != "" and base_id != only
				var row := k.flow(col)
				var give: PixelButton = k.button("Give %s to %s" % [DebugActionsScript._weapon_label(variant), m.name], func(): act(DebugActionsScript.equip_member(main, id, "weapon", vid)), true)
				k.set_enabled(give, not blocked)
				row.add_child(give)
				if blocked:
					k.note(col, "%s can only use a %s." % [m.name, only], PixelKit.BAD)
			k.section(col, "Weapons you own")
			for v in DebugActionsScript.owned_weapon_variants(main):
				var owned_id := str(v.id)
				var line := k.hbox(col, 6)
				var holder = main.player.weapon_holder(owned_id)
				var note := ""
				if str(main.player.current_weapon_base.get("id", "")) == owned_id and owned_id != "club":
					note = "   (yours)"
				elif holder != null:
					note = "   (%s)" % holder.name
				var label := PixelKit.label(DebugActionsScript._weapon_label(v) + note, "body", PixelKit.GOLD3 if m.weapon_id() == owned_id else PixelKit.CREAM)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				line.add_child(label)
				var take: PixelButton = k.button("Give to %s" % m.name, func(): act(DebugActionsScript.equip_member(main, id, "weapon", owned_id)))
				k.set_enabled(take, str(main.player.current_weapon_base.get("id", "")) != owned_id or owned_id == "club")
				line.add_child(take)
		"armor":
			var options: Array = []
			for a in ArmorScript.TIERS:
				if str(a.id) != "armor_rags":
					options.append([str(a.id), str(a.name)])
			_option_list(col, m, "armor", options, [m.armor_id()])
		"shield":
			var shield_options: Array = []
			for sid in ShieldsScript.SHIELD_IDS:
				shield_options.append([str(sid), str(ShieldsScript.SHIELDS[sid].name)])
			_option_list(col, m, "shield", shield_options, [m.shield_id()])
		"talisman":
			var tal_options: Array = []
			for t in TalismansScript.ITEMS:
				tal_options.append([str(t.id), str(t.name)])
			_option_list(col, m, "talisman", tal_options, m.talisman_ids())

# A wrap of buttons, one per item; the ones the member has now are lit, and pressing one gives it (or, for a talisman it already
# wears, takes it off again).
func _option_list(col: VBoxContainer, m, slot: String, options: Array, worn: Array) -> void:
	var k := DebugKitScript
	var id: int = int(m.id)
	var flow := k.flow(col)
	for opt in options:
		var item_id: String = str(opt[0])
		var has: bool = worn.has(item_id)
		flow.add_child(k.button(str(opt[1]), func():
			if has and slot == "talisman":
				act(DebugActionsScript.unequip_member(main, id, slot, item_id))
			else:
				act(DebugActionsScript.equip_member(main, id, slot, item_id))
		, has))
