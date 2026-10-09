extends TownPanel

# The in-game Sandbox screen (reached from the title screen's Sandbox button).
# A debug tool: configure a whole build and an enemy squad, then fight a REAL
# tile battle with it. All of the logic lives in Sandbox.gd; nothing here (or
# anything it triggers) is ever saved -- see SaveData.sandbox_active.

const SandboxScript := preload("res://scripts/Sandbox.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const FoodsScript := preload("res://scripts/Foods.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const PartyMemberScript := preload("res://scripts/PartyMember.gd")
const BlacksmithScript := preload("res://scripts/Blacksmith.gd")
const MaterialsScript := preload("res://scripts/Materials.gd")
const DojoScript := preload("res://scripts/Dojo.gd")

const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.8), "uncommon": Color(0.45, 0.85, 0.45), "rare": Color(0.45, 0.65, 1.0), "epic": Color(0.85, 0.5, 1.0),
}

var cfg: Dictionary = {}
var tabs: TabContainer
var summary_label: Label
var result_label: Label
var seed_spin: SpinBox
var start_button: Button
var back_button: Button
var _tab_box := {}
var _tab_scroll := {}
var _builders := {}
var show_noncombat := false
# The real Settings value before a sandbox battle overrode it (restored on Back).
var _orig_minigames := true
var _orig_attack_minigame := true
var _minigames_overridden := false

func _panel_title() -> String:
	return "SANDBOX"

func _window_size() -> Vector2:
	return get_viewport().get_visible_rect().size - Vector2(40, 40)

func can_close() -> bool:
	return false

func _main():
	return get_parent()

func _build_content(outer: VBoxContainer) -> void:
	cfg = SandboxScript.load_config()
	close_button.visible = false
	# opaque backdrop: the overworld behind the sandbox is irrelevant
	window.get_parent().color = Color(0.03, 0.03, 0.05, 1.0)
	title_label.text = "SANDBOX  -  pick any build, any enemies, then fight a real battle (nothing here is saved)"
	title_label.add_theme_font_size_override("font_size", 20)

	result_label = _make_label("", 14, Color(0.7, 0.9, 1.0))
	outer.add_child(result_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)
	_make_tab("Character", _build_character)
	_make_tab("Weapon", _build_weapon)
	_make_tab("Gear", _build_gear)
	_make_tab("Items", _build_items)
	_make_tab("Talismans", _build_talismans)
	_make_tab("Astral", _build_astral)
	_make_tab("Party", _build_party)
	_make_tab("Encounter", _build_encounter)
	_make_tab("Options", _build_options)

	summary_label = _make_label("", 13, Color(0.8, 0.85, 0.9))
	outer.add_child(summary_label)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	outer.add_child(bar)
	back_button = Button.new()
	back_button.text = "Back to title"
	back_button.pressed.connect(_on_back_pressed)
	bar.add_child(back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var seed_label := _inline("Seed", 13)
	seed_label.custom_minimum_size = Vector2(46, 0)
	bar.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 0
	seed_spin.max_value = 2147483647
	seed_spin.value = int(cfg.seed)
	seed_spin.custom_minimum_size = Vector2(130, 0)
	seed_spin.value_changed.connect(func(v): cfg.seed = int(v); _save())
	bar.add_child(seed_spin)
	var dice := Button.new()
	dice.text = "Random"
	dice.pressed.connect(func():
		cfg.seed = randi() % 2147483647
		seed_spin.value = cfg.seed
		_save())
	bar.add_child(dice)
	start_button = Button.new()
	start_button.text = "Start battle"
	start_button.custom_minimum_size = Vector2(200, 40)
	start_button.add_theme_font_size_override("font_size", 18)
	start_button.pressed.connect(_start_battle)
	bar.add_child(start_button)

func _on_opened() -> void:
	_apply_preview()

func _refresh() -> void:
	if tabs == null:
		return
	_apply_preview()

# ---------------------------------------------------------------- plumbing
func _make_tab(tab_name: String, builder: Callable) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	tabs.add_child(scroll)
	_tab_scroll[tab_name] = scroll
	_tab_box[tab_name] = box
	_builders[tab_name] = builder

func _fill_all_tabs() -> void:
	for tab_name in _builders:
		_fill_tab(tab_name)

func _fill_tab(tab_name: String) -> void:
	var box: VBoxContainer = _tab_box[tab_name]
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	_builders[tab_name].call(box)

func _rebuild(tab_names: Array) -> void:
	for tab_name in tab_names:
		var scroll: ScrollContainer = _tab_scroll[tab_name]
		var keep: int = scroll.scroll_vertical
		_fill_tab(tab_name)
		scroll.set_deferred("scroll_vertical", keep)

func _save() -> void:
	SandboxScript.save_config(cfg)

# Rebuilds the live player from cfg so every preview reads real numbers, then
# refreshes the summary line.
func _apply_preview() -> void:
	if _main() == null or _main().player == null:
		return
	SandboxScript.apply_build(_main(), cfg)
	if summary_label != null:
		summary_label.text = SandboxScript.summary(_main(), cfg)

func _changed(rebuild_tabs: Array = []) -> void:
	_save()
	_apply_preview()
	_rebuild(rebuild_tabs)

func _pl():
	return _main().player

func _row(parent: Node, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lab := _make_label(label_text, 14, Color(0.7, 0.72, 0.78))
	lab.custom_minimum_size = Vector2(170, 0)
	row.add_child(lab)
	parent.add_child(row)
	return row

func _heading(parent: Node, text: String) -> void:
	parent.add_child(_make_label(text, 17, Color(1, 0.9, 0.3)))

func _spin(parent: Node, value, lo, hi, on_change: Callable, step := 1.0) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = value
	sb.custom_minimum_size = Vector2(100, 0)
	sb.value_changed.connect(func(v): on_change.call(v))
	parent.add_child(sb)
	return sb

func _option(parent: Node, items: Array, current, on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	var chosen := 0
	for i in items.size():
		ob.add_item(str(items[i][1]))
		ob.set_item_metadata(i, items[i][0])
		if items[i][0] == current:
			chosen = i
	if items.size() > 0:
		ob.select(chosen)
	ob.item_selected.connect(func(i): on_pick.call(ob.get_item_metadata(i)))
	parent.add_child(ob)
	return ob

func _button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b

func _check(parent: Node, text: String, value: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = value
	cb.toggled.connect(func(v): on_toggle.call(v))
	parent.add_child(cb)
	return cb

func _stepper(parent: Node, value: int, on_dec: Callable, on_inc: Callable) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_button(box, "-", on_dec)
	var l := _inline(str(value), 14)
	l.custom_minimum_size = Vector2(34, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	_button(box, "+", on_inc)
	parent.add_child(box)

# A short label that sits in a row and never wraps.
func _inline(text: String, font_size: int = 14, color: Color = Color(0.85, 0.85, 0.8)) -> Label:
	var l := _make_label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

# A description that sits in a row: takes the remaining width and wraps.
func _desc(text: String, color: Color = Color(0.6, 0.6, 0.66)) -> Label:
	var l := _make_label(text, 12, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(320, 0)
	return l

func _note(parent: Node, text: String, color := Color(0.62, 0.62, 0.68)) -> Label:
	var l := _make_label(text, 12, color)
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

# ---------------------------------------------------------------- Character
func _picks_used() -> int:
	var used := 0
	for s in SandboxScript.pickable_stats(_pl()):
		used += int(cfg.picks.get(s, 0))
	return used

func _trim_picks() -> void:
	var allowed: int = int(cfg.level) - 1
	for s in cfg.picks.keys():
		var excess: int = _picks_used() - allowed
		if excess <= 0:
			break
		cfg.picks[s] = maxi(0, int(cfg.picks[s]) - excess)

func _pick(stat: String, delta: int) -> void:
	var cur: int = int(cfg.picks.get(stat, 0))
	if delta > 0 and _picks_used() >= int(cfg.level) - 1:
		return
	cfg.picks[stat] = maxi(0, cur + delta)
	_changed(["Character"])

func _fill_picks(mode: String) -> void:
	cfg.picks = {}
	var total: int = int(cfg.level) - 1
	if mode == "balanced":
		var core := ["strength", "vigor", "agility", "might", "intimidation"]
		for i in total:
			var s: String = core[i % core.size()]
			cfg.picks[s] = int(cfg.picks.get(s, 0)) + 1
	elif mode != "reset":
		cfg.picks[mode] = total
	_changed(["Character"])

func _build_character(box: VBoxContainer) -> void:
	var p = _pl()
	_heading(box, "Fighter")
	var r := _row(box, "Level")
	_spin(r, cfg.level, 1, 99, func(v):
		cfg.level = int(v)
		_trim_picks()
		_changed(["Character", "Talismans", "Weapon"]))
	var r2 := _row(box, "Difficulty")
	var diffs := []
	for d in SaveDataScript.DIFFICULTIES:
		diffs.append([d.id, "%s (x%s)" % [d.name, str(d.mult)]])
	_option(r2, diffs, cfg.difficulty, func(v):
		cfg.difficulty = v
		_changed())
	var r3 := _row(box, "Coins")
	_spin(r3, cfg.coins, 0, 99999, func(v):
		cfg.coins = int(v)
		_changed())
	var r4 := _row(box, "Waves cleared this run")
	_spin(r4, cfg.waves_cleared, 0, 200, func(v):
		cfg.waves_cleared = int(v)
		_changed(["Character"]))
	_note(box, "(Waves cleared only matters for the Hardened upgrade: +HP per wave.)")
	_heading(box, "Stat points")
	_note(box, "Every level-up gives +1 to each core stat automatically, plus ONE bonus point you place here (level - 1 in total).")
	var per_agility: int = PlayerScriptConst().AGILITY_BONUS_PER_LEVEL + p.meta_levelup_bonus_agility
	for s in SandboxScript.pickable_stats(p):
		var per: int = 1
		match s:
			"agility": per = per_agility
			"strength": per = 1 + p.meta_levelup_bonus_strength
			"vigor": per = 1 + p.meta_levelup_bonus_vigor
			"intimidation": per = 1 + p.meta_levelup_bonus_intimidation
		if p.meta_bonus_levelup_stat:
			per *= 2
		var row := _row(box, "%s  (%d)" % [s.capitalize(), int(p.get("stat_%s" % s))])
		var stat: String = s
		_stepper(row, int(cfg.picks.get(s, 0)), func(): _pick(stat, -1), func(): _pick(stat, 1))
		row.add_child(_inline("+%d per point" % per, 12, Color(0.6, 0.6, 0.66)))
	var left: int = int(cfg.level) - 1 - _picks_used()
	_note(box, "Unspent points: %d" % left, Color(1, 0.8, 0.5) if left > 0 else Color(0.62, 0.62, 0.68))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	box.add_child(presets)
	_button(presets, "All Strength", func(): _fill_picks("strength"))
	_button(presets, "All Vigor", func(): _fill_picks("vigor"))
	_button(presets, "Balanced", func(): _fill_picks("balanced"))
	_button(presets, "Reset", func(): _fill_picks("reset"))
	_heading(box, "Resulting stats")
	var move_range: int = 2 + maxi(0, int((p.stat_agility - PlayerScriptConst().AGILITY_START) / 20)) + int(p.talisman_bonus("move_range"))
	var lines := [
		"Max HP: %d" % p.max_health, "Attack (base damage): %d" % p.attack_damage, "Battle move range: %d tiles" % move_range,
		"Stamina: %d (battle start: %d)" % [p.max_stamina, int(round(p.max_stamina * PlayerScriptConst().BATTLE_START_STAMINA_PCT))],
		"Crit chance: %.1f%%   Dodge chance: %.1f%%" % [p.crit_chance_total() * 100.0, p.dodge_chance_total() * 100.0],
		"Bodily harm reduction (armor + clothes + shield + resilience): %.1f%%   Magical harm reduction (Fortitude %d): %.1f%%" % [minf(0.9, p.armor_damage_reduction() + p.resilience_reduction + p.meta_war_chest_reduction + p.shield_damage_reduction_pct()) * 100.0, int(p.fortitude_total()), p.fortitude_reduction() * 100.0],
		"Talisman slots: %d" % TalismansScript.slots_for_level(p.level),
	]
	_note(box, "\n".join(lines), Color(0.8, 0.85, 0.9))

func PlayerScriptConst():
	return preload("res://scripts/Player.gd")

# ---------------------------------------------------------------- Weapon
func _build_weapon(box: VBoxContainer) -> void:
	var p = _pl()
	var sel: Dictionary = cfg.weapon
	var is_club: bool = sel.base == "club"
	var is_mythic: bool = sel.tier == "Mythic" and WeaponsScript.MYTHIC_WEAPONS.has(sel.base)
	_heading(box, "Weapon")
	var items := []
	for b in SandboxScript.weapon_bases():
		items.append([b.id, b.name])
	_option(_row(box, "Weapon"), items, sel.base, func(v):
		cfg.weapon.base = v
		if v == "club":
			cfg.weapon.tier = "Fine"
		_changed(["Weapon", "Talismans"]))
	var tier_items := []
	for t in WeaponsScript.TIERS:
		var extra := ""
		if t.required_might > 0:
			extra += ", Might %d" % t.required_might
		if t.get("required_intimidation", 0) > 0:
			extra += ", Intimidation %d" % t.required_intimidation
		tier_items.append([t.tier_name, "%s (x%s dmg%s)" % [t.tier_name, str(t.damage_scale), extra]])
	var tier_opt := _option(_row(box, "Quality"), tier_items, sel.tier, func(v):
		cfg.weapon.tier = v
		_changed(["Weapon", "Talismans"]))
	tier_opt.disabled = is_club
	var mat_items := []
	for m in WeaponsScript.MATERIALS:
		mat_items.append([m.id, "%s (x%s dmg, x%s stamina%s)" % [m.name, str(m.damage_scale), str(m.stamina_scale), (", %d%% break" % int(round(m.break_chance * 100.0))) if m.break_chance > 0.0 else ""]])
	var mat_opt := _option(_row(box, "Material"), mat_items, sel.material, func(v):
		cfg.weapon.material = v
		_changed(["Weapon", "Talismans"]))
	mat_opt.disabled = is_club or is_mythic
	_spin(_row(box, "Blacksmith level"), cfg.blacksmith, 0, BlacksmithScript.WEAPON_MAX_LEVEL, func(v):
		cfg.blacksmith = int(v)
		_changed(["Weapon"]))
	var rune_items := [["", "None"]]
	for r in EnchantmentsScript.RUNES:
		rune_items.append([r.id, r.name])
	var rune_opt := _option(_row(box, "Rune"), rune_items, cfg.rune, func(v):
		cfg.rune = v
		_changed(["Weapon"]))
	rune_opt.disabled = is_club
	_check(box, "All specials learned at the Dojo (also halves the miss chance)", bool(cfg.learn_all), func(v):
		cfg.learn_all = v
		_changed(["Weapon"]))
	var w: Dictionary = p.current_weapon
	var warns := []
	if int(w.get("required_might", 0)) > p.stat_might:
		warns.append("needs Might %d (you have %d)" % [w.required_might, p.stat_might])
	if int(w.get("required_intimidation", 0)) > p.stat_intimidation:
		warns.append("needs Intimidation %d (you have %d)" % [w.required_intimidation, p.stat_intimidation])
	if not warns.is_empty():
		_note(box, "Not equippable in a real run until: %s." % "; ".join(warns), Color(1, 0.75, 0.4))
	_heading(box, String(w.get("name", "Weapon")))
	var lines := [
		"Damage multiplier: %.3f" % w.damage_mult,
		"Plain hit: %d damage (Attack %d)" % [int(round(p.attack_damage * w.damage_mult)), p.attack_damage],
		"Heavy attack (x%s, %d stamina): %d damage" % [str(WeaponsScript.HEAVY_DAMAGE_MULT), int(w.get("heavy_stamina_cost_override", WeaponsScript.HEAVY_STAMINA_COST)), int(round(p.attack_damage * w.damage_mult * WeaponsScript.HEAVY_DAMAGE_MULT))],
		"Range: %s" % ("whole grid" if w.get("passive_unlimited_range", false) else "%d tile(s)" % ((2 if w.get("long_range", false) else 1) + int(w.get("passive_extra_range", 0)))),
		"Break chance per hit: %.1f%%" % (float(w.get("break_chance", 0.0)) * 100.0),
	]
	if w.has("regular_attack_stamina_cost"):
		lines.append("Regular attack costs %d stamina" % int(w.regular_attack_stamina_cost))
	for key in w:
		if str(key).begins_with("passive_"):
			lines.append("Passive: %s = %s" % [str(key).trim_prefix("passive_"), str(w[key])])
	for sp in w.get("specials", []):
		var hits := ""
		if sp.has("hit_count_max"):
			hits = " x%d-%d hits" % [sp.hit_count_min, sp.hit_count_max]
		elif sp.has("pass_count_max"):
			hits = " x%d-%d passes" % [sp.pass_count_min, sp.pass_count_max]
		lines.append("Special: %s (%d stamina, %d%%%s) -- %s" % [sp.name, int(sp.stamina_cost), int(round(float(sp.get("dmg_mult", 0.0)) * 100.0)), hits, str(sp.get("description", ""))])
	_note(box, "\n".join(lines), Color(0.8, 0.85, 0.9))

# ---------------------------------------------------------------- Gear
func _build_gear(box: VBoxContainer) -> void:
	_heading(box, "Armor")
	var armor_items := []
	for a in ArmorScript.TIERS:
		armor_items.append([a.id, "%s (-%d%% bodily, %+d Fortitude%s)" % [a.name, int(round(a.damage_reduction * 100.0)), int(a.fortitude), ", crafted" if a.has("recipe") else ""]])
	_option(_row(box, "Armor"), armor_items, cfg.armor, func(v):
		cfg.armor = v
		_changed(["Gear", "Character"]))
	var armor: Dictionary = SandboxScript.find_in(ArmorScript.TIERS, "id", cfg.armor)
	var smith := _spin(_row(box, "Smithing level"), cfg.armor_level if armor.get("metal", false) else 0, 0, BlacksmithScript.ARMOR_MAX_LEVEL, func(v):
		cfg.armor_level = int(v)
		_changed(["Character"]))
	smith.editable = armor.get("metal", false)
	_note(box, "+2.5% damage reduction per level (metal armor only).")
	_note(box, str(armor.get("description", "")), Color(0.8, 0.85, 0.9))
	_heading(box, "Crafting materials")
	if not cfg.has("materials"):
		cfg["materials"] = {}
	for material_id in MaterialsScript.ITEMS:
		var mat_id: String = material_id
		_spin(_row(box, MaterialsScript.name_of(mat_id)), int(cfg.materials.get(mat_id, 0)), 0, 99, func(v):
			cfg.materials[mat_id] = int(v)
			_changed(["Character"]))
	_note(box, "Spent at the Blacksmith's Commissions to make the pelt armours.")
	_heading(box, "Clothing")
	for slot in ["head", "body", "feet"]:
		var items := [["", "None"]]
		for c in ClothingScript.for_slot(slot):
			items.append([c.id, "%s (-%d%%)" % [c.name, int(round(c.damage_reduction * 100.0))]])
		var slot_name: String = slot
		_option(_row(box, slot.capitalize()), items, cfg.clothing.get(slot, ""), func(v):
			cfg.clothing[slot_name] = v
			_changed(["Character"]))
	_heading(box, "Shield")
	var shield_items := [["", "None"]]
	for id in ShieldsScript.SHIELD_IDS:
		shield_items.append([id, ShieldsScript.SHIELDS[id].name])
	_option(_row(box, "Shield"), shield_items, cfg.shield, func(v):
		cfg.shield = v
		_changed(["Gear", "Character"]))
	if cfg.shield != "":
		_note(box, str(ShieldsScript.SHIELDS[cfg.shield].description))
	else:
		_note(box, "Shields only work with club, spear, hammer, dagger and knuckle gloves (unless the Unbreakable Guard upgrade is owned).")

# ---------------------------------------------------------------- Items
func _item_count(id: String) -> int:
	for e in cfg.consumables:
		if str(e.id) == id:
			return int(e.n)
	return 0

func _set_item_count(id: String, n: int) -> void:
	var counts := {}
	for e in cfg.consumables:
		counts[str(e.id)] = int(e.n)
	counts[id] = n
	var list := []
	for t in PotionsScript.TIERS:
		if int(counts.get(t.id, 0)) > 0:
			list.append({"id": t.id, "n": int(counts[t.id])})
	for f in FoodsScript.ITEMS:
		if int(counts.get(f.id, 0)) > 0:
			list.append({"id": f.id, "n": int(counts[f.id])})
	cfg.consumables = list
	_changed()

func _build_items(box: VBoxContainer) -> void:
	_heading(box, "Potions & food (used in this order: potions first, then food)")
	for t in PotionsScript.TIERS:
		var item_id: String = t.id
		var row := _row(box, str(t.name))
		_spin(row, _item_count(item_id), 0, 99, func(v): _set_item_count(item_id, int(v)))
		row.add_child(_desc(str(t.description)))
	for f in FoodsScript.ITEMS:
		var item_id: String = f.id
		var row := _row(box, str(f.name))
		_spin(row, _item_count(item_id), 0, 99, func(v): _set_item_count(item_id, int(v)))
		row.add_child(_desc(str(f.description)))
	_heading(box, "Special arrows (used with a Bow)")
	for kind in ["flame", "freeze", "bomb"]:
		var k: String = kind
		_spin(_row(box, "%s arrows" % k.capitalize()), int(cfg.arrows.get(k, 0)), 0, 99, func(v):
			cfg.arrows[k] = int(v)
			_changed())

# ---------------------------------------------------------------- Talismans
func _build_talismans(box: VBoxContainer) -> void:
	var slots: int = TalismansScript.slots_for_level(_pl().level)
	_heading(box, "Talismans")
	var info := _row(box, "Slots")
	info.add_child(_inline("%d / %d used (level %d)" % [cfg.talismans.size(), slots, int(cfg.level)], 14))
	_check(info, "Ignore the slot limit", bool(cfg.ignore_slots), func(v):
		cfg.ignore_slots = v
		_changed(["Talismans"]))
	if cfg.talismans.size() > slots and not cfg.ignore_slots:
		_note(box, "Over the slot limit -- only the first %d will be worn." % slots, Color(1, 0.75, 0.4))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for t in TalismansScript.ITEMS:
		var tid: String = t.id
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = cfg.talismans.has(tid)
		b.text = "%s  [%s]" % [t.name, t.rarity]
		b.tooltip_text = str(t.description)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", RARITY_COLORS.get(t.rarity, Color.WHITE))
		b.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.5))
		b.toggled.connect(func(on):
			if on and not cfg.talismans.has(tid):
				cfg.talismans.append(tid)
			elif not on:
				cfg.talismans.erase(tid)
			_changed(["Talismans"]))
		grid.add_child(b)
	_note(box, "Hover a talisman for its description.")
	if cfg.talismans.has("weapon_whisperer"):
		_heading(box, "Weapon Whisperer loadout (pick up to 3 specials from any weapon)")
		var all_specials := [["", "-- (the weapon's own)"]]
		for b2 in SandboxScript.weapon_bases():
			for sp in b2.get("specials", []):
				all_specials.append([sp.id, "%s: %s" % [b2.name, sp.name]])
		for i in 3:
			var slot_index: int = i
			var current: String = str(cfg.whisperer[i]) if i < cfg.whisperer.size() else ""
			_option(_row(box, "Slot %d" % (i + 1)), all_specials, current, func(v):
				while cfg.whisperer.size() <= slot_index:
					cfg.whisperer.append("")
				cfg.whisperer[slot_index] = v
				_changed())

# ---------------------------------------------------------------- Astral upgrades
func _build_astral(box: VBoxContainer) -> void:
	_heading(box, "Astral (permanent) upgrades")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	_button(top, "Clear all", func():
		cfg.upgrades = {}
		_changed(["Astral", "Character", "Party"]))
	_button(top, "Max combat upgrades", func():
		for id in SandboxScript.COMBAT_UPGRADES:
			if SaveDataScript.UPGRADES.has(id) and id != "worldwalker":
				cfg.upgrades[id] = int(SaveDataScript.UPGRADES[id].get("max_level", 3))
		_changed(["Astral", "Character", "Party"]))
	_check(top, "Show non-combat upgrades", show_noncombat, func(v):
		show_noncombat = v
		_rebuild(["Astral"]))
	_note(box, "Levels are set directly -- prerequisites and Essence costs are ignored here (a warning shows if a prerequisite is missing).")
	for id in SaveDataScript.UPGRADE_IDS:
		if not show_noncombat and not SandboxScript.COMBAT_UPGRADES.has(id):
			continue
		var def: Dictionary = SaveDataScript.UPGRADES[id]
		var upgrade_id: String = id
		var level: int = int(cfg.upgrades.get(id, 0))
		var max_level: int = int(def.get("max_level", 10))
		var row := _row(box, str(def.name) + ("  (max %d)" % def.max_level if def.has("max_level") else ""))
		_stepper(row, level, func():
			cfg.upgrades[upgrade_id] = maxi(0, int(cfg.upgrades.get(upgrade_id, 0)) - 1)
			if int(cfg.upgrades[upgrade_id]) == 0:
				cfg.upgrades.erase(upgrade_id)
			_changed(["Astral", "Character", "Party"]),
			func():
				cfg.upgrades[upgrade_id] = mini(max_level, int(cfg.upgrades.get(upgrade_id, 0)) + 1)
				_changed(["Astral", "Character", "Party"]))
		var missing := []
		for pre in def.get("prereqs", []):
			if int(cfg.upgrades.get(pre.id, 0)) < int(pre.min_level):
				missing.append("%s %d" % [SaveDataScript.UPGRADES[pre.id].name, int(pre.min_level)])
		var text: String = str(def.description)
		if level > 0 and not missing.is_empty():
			text += "   [prerequisite not met in a real run: %s]" % ", ".join(missing)
		row.add_child(_desc(text, Color(0.62, 0.62, 0.68) if missing.is_empty() or level == 0 else Color(1, 0.75, 0.4)))

# ---------------------------------------------------------------- Party
func _build_party(box: VBoxContainer) -> void:
	var p = _pl()
	_heading(box, "Party")
	var cap: int = p.party_capacity()
	_note(box, "Capacity %d / %d (wolves and mercenaries count; raise it with Pack Leader / Warlord / Wolf Fang). Allies fight when you command them each round." % [p.party_members.size() + p.party.size(), cap])
	for m in p.party_members:
		_note(box, "%s (granted by an Astral upgrade)" % str(m.get("name", "Ally")), Color(0.6, 0.9, 0.6))
	if int(cfg.upgrades.get("beastmaster", 0)) > 0:
		_note(box, "Traitor Wolf (granted by Beastmaster)", Color(0.6, 0.9, 0.6))
	for i in cfg.party.size():
		var entry: Dictionary = cfg.party[i]
		var rules: Dictionary = PartyRulesScript.rules(str(entry.kind))
		var index: int = i
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		box.add_child(card)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		card.add_child(head)
		head.add_child(_inline(str(rules.get("name", entry.kind)), 15, Color(1, 0.9, 0.3)))
		if rules.get("levels", true):
			head.add_child(_inline("Level", 13))
			_spin(head, int(entry.level), 1, 99, func(v):
				cfg.party[index].level = int(v)
				_trim_party_picks(index)
				_changed(["Party"]))
		_button(head, "Remove", func():
			cfg.party.remove_at(index)
			_changed(["Party"]))
		var pm = PartyMemberScript.create(1, str(entry.kind))
		if rules.get("levels", true):
			for l in range(int(entry.level) - 1):
				pm._level_up()
			var picks: Dictionary = entry.get("picks", {})
			for stat in picks:
				for n in int(picks[stat]):
					pm.spend_pick(str(stat))
		card.add_child(_make_label("HP %d | ATK %.1f | DEF %.1f%% | MAG %.1f | move %d | range %d" % [pm.max_hp(), pm.attack(), pm.defense_pct(), pm.magic(), pm.move_tiles(), int(rules.get("attack_range", 1))], 12, Color(0.7, 0.75, 0.8)))
		if PartyRulesScript.can_carry_gear(str(entry.kind)):
			_party_gear_rows(card, index)
		if rules.get("levels", true):
			var pick_row := HBoxContainer.new()
			pick_row.add_theme_constant_override("separation", 12)
			card.add_child(pick_row)
			var picks_used := 0
			for s in rules.get("stats", []):
				picks_used += int(entry.get("picks", {}).get(s, 0))
			for s in rules.get("stats", []):
				var stat_name: String = s
				pick_row.add_child(_inline(stat_name, 12))
				_stepper(pick_row, int(entry.get("picks", {}).get(stat_name, 0)), func(): _party_pick(index, stat_name, -1), func(): _party_pick(index, stat_name, 1))
			pick_row.add_child(_inline("(%d points left)" % (int(entry.level) - 1 - picks_used), 12, Color(0.6, 0.6, 0.66)))
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	box.add_child(add_row)
	var kinds := []
	for k in PartyRulesScript.KINDS:
		kinds.append([k, PartyRulesScript.KINDS[k].name])
	var kind_pick := _option(add_row, kinds, "wolf", func(_v): pass)
	_button(add_row, "Add member", func():
		cfg.party.append({"kind": kind_pick.get_item_metadata(kind_pick.selected), "level": 1, "picks": {}})
		_changed(["Party"]))
	_note(box, "Members can carry any weapon (the Staff is for party members only) and talismans from their own slots (1/2/3/4 at levels 1/4/8/12). Each item goes to one unit at a time.")

# A member's weapon (base, quality, material) and talismans, kept in cfg.party[index].
func _party_gear_rows(card: VBoxContainer, index: int) -> void:
	var entry: Dictionary = cfg.party[index]
	var wsel: Dictionary = entry.get("weapon", {"base": "", "tier": "Fine", "material": "steel"})
	var base_id: String = str(wsel.get("base", ""))
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 8)
	card.add_child(weapon_row)
	weapon_row.add_child(_inline("Weapon", 12))
	var base_items := [["", "(bare hands)"]]
	for b in SandboxScript.party_weapon_bases():
		base_items.append([b.id, b.name])
	_option(weapon_row, base_items, base_id, func(v):
		cfg.party[index]["weapon"] = {"base": v, "tier": wsel.get("tier", "Fine"), "material": wsel.get("material", "steel")}
		_changed(["Party"]))
	if base_id != "" and base_id != "club":
		var tier_items := []
		for t in WeaponsScript.TIERS:
			tier_items.append([t.tier_name, t.tier_name])
		_option(weapon_row, tier_items, str(wsel.get("tier", "Fine")), func(v):
			cfg.party[index].weapon["tier"] = v
			_changed(["Party"]))
		if str(wsel.get("tier", "Fine")) != "Mythic":
			var mat_items := []
			for m in WeaponsScript.MATERIALS:
				mat_items.append([m.id, m.name])
			_option(weapon_row, mat_items, str(wsel.get("material", "steel")), func(v):
				cfg.party[index].weapon["material"] = v
				_changed(["Party"]))
	var slots: int = PartyRulesScript.talisman_slots(str(entry.kind), int(entry.level))
	var worn: Array = entry.get("talismans", [])
	var talisman_row := HBoxContainer.new()
	talisman_row.add_theme_constant_override("separation", 6)
	card.add_child(talisman_row)
	talisman_row.add_child(_inline("Talismans %d/%d" % [mini(worn.size(), slots), slots], 12))
	for id in worn:
		var t: Dictionary = TalismansScript.get_talisman(str(id))
		var talisman_id: String = str(id)
		_button(talisman_row, "%s ✕" % t.get("name", talisman_id), func():
			cfg.party[index].talismans.erase(talisman_id)
			_changed(["Party"]))
	if worn.size() < slots:
		var tal_items := [["", "+ add a talisman"]]
		for item in TalismansScript.ITEMS:
			if not worn.has(item.id):
				tal_items.append([item.id, item.name])
		_option(talisman_row, tal_items, "", func(v):
			if str(v) == "":
				return
			if not cfg.party[index].has("talismans"):
				cfg.party[index]["talismans"] = []
			cfg.party[index].talismans.append(str(v))
			_changed(["Party"]))

func _party_picks_used(index: int) -> int:
	var rules: Dictionary = PartyRulesScript.rules(str(cfg.party[index].kind))
	var used := 0
	for s in rules.get("stats", []):
		used += int(cfg.party[index].get("picks", {}).get(s, 0))
	return used

func _trim_party_picks(index: int) -> void:
	var picks: Dictionary = cfg.party[index].get("picks", {})
	for s in picks.keys():
		var excess: int = _party_picks_used(index) - (int(cfg.party[index].level) - 1)
		if excess <= 0:
			break
		picks[s] = maxi(0, int(picks[s]) - excess)

func _party_pick(index: int, stat: String, delta: int) -> void:
	if not cfg.party[index].has("picks"):
		cfg.party[index]["picks"] = {}
	if delta > 0 and _party_picks_used(index) >= int(cfg.party[index].level) - 1:
		return
	cfg.party[index].picks[stat] = maxi(0, int(cfg.party[index].picks.get(stat, 0)) + delta)
	_changed(["Party"])

# ---------------------------------------------------------------- Encounter
func _enemy_option_items(main) -> Array:
	var items := []
	var seen := {}
	for e in SandboxScript.enemy_catalog():
		if seen.has(e.name):
			continue
		seen[e.name] = true
		items.append([e.name, "%s%s" % [e.name, "  [boss]" if SandboxScript.is_boss(main, e.name) else ""]])
	return items

func _build_encounter(box: VBoxContainer) -> void:
	var main = _main()
	_heading(box, "Battlefield")
	var worlds := []
	for w in main.WORLDS:
		var t: String = "" if w.terrain.is_empty() else " (%s)" % ", ".join(w.terrain)
		worlds.append([w.id, "%s%s" % [w.name, t]])
	_option(_row(box, "World"), worlds, cfg.world, func(v):
		cfg.world = v
		_changed())
	var preset_row := _row(box, "Squad preset")
	var presets := [["", "-- load a squad --"]]
	for i in SandboxScript.SQUAD_PRESETS.size():
		presets.append(["p%d" % i, SandboxScript.SQUAD_PRESETS[i][0]])
	for i in 10:
		var w: Dictionary = main.WORLDS[i]
		presets.append(["m%d" % i, "%s: %s" % [w.name, _boss_name(main, w.miniboss_script)]])
		presets.append(["b%d" % i, "%s: %s" % [w.name, _boss_name(main, w.boss_script)]])
	_option(preset_row, presets, "", func(v):
		_load_preset(str(v))
		_changed(["Encounter"]))
	_heading(box, "Enemies")
	var items := _enemy_option_items(main)
	for i in cfg.enemies.size():
		var e: Dictionary = cfg.enemies[i]
		var index: int = i
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 10)
		box.add_child(card)
		_option(card, items, e.name, func(v):
			cfg.enemies[index].name = v
			_changed(["Encounter"]))
		_check(card, "Elite", bool(e.get("elite", false)), func(on):
			cfg.enemies[index].elite = on
			_changed(["Encounter"]))
		card.add_child(_inline("Power x", 13))
		_spin(card, float(e.get("power_tier", 1.0)), 0.1, 10.0, func(v):
			cfg.enemies[index].power_tier = float(v)
			_save(), 0.05)
		var nth: int = SandboxScript.NOTHINGNESS_ORDER.find(e.name)
		if nth >= 0:
			_button(card, "Nothingness power", func():
				cfg.enemies[index].power_tier = float(main.NOTHINGNESS_POWER_TIERS[nth])
				_changed(["Encounter"]))
		_button(card, "Remove", func():
			cfg.enemies.remove_at(index)
			_changed(["Encounter"]))
		var info := ""
		for entry in SandboxScript.enemy_catalog():
			if entry.name == e.name:
				info = "base HP %d, damage %d, XP %d" % [entry.hp, entry.dmg, entry.xp]
				break
		if SandboxScript.is_boss(main, e.name):
			info += "  | boss (a lone boss fights on the 15x15 grid)"
		if main.ENEMY_TRAITS.get(e.name, {}).get("armored", false):
			info += "  | armored"
		box.add_child(_make_label("    " + info, 12, Color(0.6, 0.6, 0.66)))
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	box.add_child(add_row)
	var add_pick := _option(add_row, items, "Goblin", func(_v): pass)
	_button(add_row, "Add enemy", func():
		cfg.enemies.append({"name": add_pick.get_item_metadata(add_pick.selected), "elite": false, "power_tier": 1.0})
		_changed(["Encounter"]))
	var diff_mult: float = SaveDataScript.get_difficulty_mult(str(cfg.difficulty))
	_note(box, "Enemy stats scale x%.2f (regular) / x%.2f (boss and miniboss) with your level, x%s with the difficulty, x%s HP / x%s damage for elites." % [main._enemy_level_scale(false), main._enemy_level_scale(true), str(diff_mult), str(main.ELITE_HP_MULT), str(main.ELITE_DAMAGE_MULT)])

func _boss_name(_main_ref, script) -> String:
	var inst = script.new()
	var n: String = inst.get_display_name()
	inst.free()
	return n

func _load_preset(id: String) -> void:
	var main = _main()
	if id.begins_with("p"):
		cfg.enemies = []
		for n in SandboxScript.SQUAD_PRESETS[int(id.substr(1))][1]:
			cfg.enemies.append({"name": n, "elite": false, "power_tier": 1.0})
	elif id.begins_with("m") or id.begins_with("b"):
		var w: Dictionary = main.WORLDS[int(id.substr(1))]
		var boss_script = w.miniboss_script if id.begins_with("m") else w.boss_script
		cfg.enemies = [{"name": _boss_name(main, boss_script), "elite": false, "power_tier": 1.0}]
		cfg.world = w.id

# ---------------------------------------------------------------- Options
func _build_options(box: VBoxContainer) -> void:
	_heading(box, "Options")
	_note(box, "The sandbox never writes to your real save slots: Essence, Church upgrades, the Beastiary and lifetime stats are untouched. Only this configuration is remembered (user://sandbox_config.json).")
	_button(box, "Reset the whole configuration", func():
		cfg = SandboxScript.default_config()
		seed_spin.value = int(cfg.seed)
		_save()
		_apply_preview()
		_fill_all_tabs())
	_heading(box, "Combat timing minigames")
	_note(box, "The dodge / block popups that open when an enemy attacks you. Pick one type to practise it on every attack.")
	var mg_row := _row(box, "Minigames")
	_option(mg_row, [["setting", "Follow the Settings menu"], ["random", "On (dodge or block by the odds)"], ["dodge", "On: always dodge"], ["block", "On: always block"], ["off", "Off (classic rolls)"]], str(cfg.get("minigames", "setting")), func(v):
		cfg.minigames = v
		_save())
	var atk_row := _row(box, "Attack minigame")
	_option(atk_row, [["setting", "Follow the Settings menu"], ["on", "On (weapon timing popup)"], ["off", "Off (attacks deal normal damage)"]], str(cfg.get("attack_minigame", "setting")), func(v):
		cfg.attack_minigame = v
		_save())
	_note(box, "The battle uses the real game code (Main.gd). For fast balance sweeps over hundreds of battles use battle_simulator.html at the project root -- it is parity-checked against this game.")

# ---------------------------------------------------------------- starting / returning from a battle
func _start_battle() -> void:
	var main = _main()
	if cfg.enemies.is_empty():
		result_label.text = "Add at least one enemy on the Encounter tab first."
		return
	_save()
	SandboxScript.apply_build(main, cfg)
	SandboxScript.clear_enemies(main)
	var squad: Array = SandboxScript.build_squad(main, cfg)
	if squad.is_empty():
		result_label.text = "None of the chosen enemies could be created."
		return
	seed(int(cfg.seed))
	_apply_minigame_choice(main)
	visible = false
	main.start_sandbox_battle(squad, SandboxScript.world_index(main, str(cfg.world)))

# Called by Main when a sandbox battle ends (victory / fled / defeat).
func return_from_battle(result: String, details: String) -> void:
	SandboxScript.clear_enemies(_main())
	get_tree().paused = true
	visible = true
	result_label.text = "Last battle: %s. %s" % [result.to_upper(), details]
	_apply_preview()
	_fill_all_tabs()

# Applies the Options tab's minigame choice to this session only (never saved to settings.json);
# _on_back_pressed puts the real Settings value back.
func _apply_minigame_choice(main) -> void:
	var choice: String = str(cfg.get("minigames", "setting"))
	var atk_choice: String = str(cfg.get("attack_minigame", "setting"))
	if not _minigames_overridden:
		_orig_minigames = main.settings.combat_minigames_enabled
		_orig_attack_minigame = main.settings.attack_minigame_enabled
	if atk_choice == "setting":
		main.settings.attack_minigame_enabled = _orig_attack_minigame
	else:
		_minigames_overridden = true
		main.settings.attack_minigame_enabled = atk_choice == "on"
	if choice == "setting":
		main.settings.combat_minigames_enabled = _orig_minigames
		main.debug_minigame_mode = ""
		return
	_minigames_overridden = true
	main.settings.combat_minigames_enabled = choice != "off"
	main.debug_minigame_mode = choice if (choice == "dodge" or choice == "block") else ""

func _on_back_pressed() -> void:
	if _minigames_overridden:
		_main().settings.combat_minigames_enabled = _orig_minigames
		_main().settings.attack_minigame_enabled = _orig_attack_minigame
	SaveDataScript.sandbox_active = false
	SaveDataScript.sandbox_data = {}
	get_tree().paused = false
	get_tree().change_scene_to_file("res://TitleScreen.tscn")

func _ready() -> void:
	super._ready()
	_fill_all_tabs()
