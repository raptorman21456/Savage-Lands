extends RefCounted

# The Debug menu's hands, part 4: permanent progress (the Church's upgrades, the lifetime flags, spell upgrades, the Beastiary)
# and the game itself (time, the slot's save, a state dump, collision view). Same rules as DebugActions.gd: everything goes
# through SaveData / Player / Main functions and returns {ok, msg}. In the Sandbox SaveData is in-memory, so none of this
# can reach the real save files there; the tests run against scratch files.

const DebugActionsScript := preload("res://scripts/DebugActions.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const SpellUpgradesScript := preload("res://scripts/SpellUpgrades.gd")
const HUDScript := preload("res://scripts/HUD.gd")

# Church upgrades with no ceiling of their own are "maxed" to this many levels by Max all (a debug figure, not a design one).
const UNLIMITED_LEVEL := 5

static func ok(msg: String, extra: Dictionary = {}) -> Dictionary:
	return DebugActionsScript.ok(msg, extra)

static func fail(msg: String) -> Dictionary:
	return DebugActionsScript.fail(msg)

# ---------------------------------------------------------------------------------------------------------------------------
# Church upgrades -- generic over SaveData.UPGRADES (another worker is rewriting that table), never by id
# ---------------------------------------------------------------------------------------------------------------------------

static func upgrade_ids() -> Array:
	var ids: Array = []
	for id in SaveDataScript.UPGRADE_IDS:
		if SaveDataScript.UPGRADES.has(id):
			ids.append(str(id))
	for id in SaveDataScript.UPGRADES:
		if not ids.has(str(id)):
			ids.append(str(id))
	return ids

static func upgrade_max(id: String) -> int:
	return int(SaveDataScript.UPGRADES.get(id, {}).get("max_level", UNLIMITED_LEVEL))

static func upgrade_level(id: String) -> int:
	return int(SaveDataScript.load_data().get("upgrades", {}).get(id, 0))

# [{id, name, level, max, capped (a real ceiling), unlocked (its prerequisites are met), description}] for every upgrade there is.
static func upgrade_rows() -> Array:
	var data: Dictionary = SaveDataScript.load_data()
	var owned: Dictionary = data.get("upgrades", {})
	var out: Array = []
	for id in upgrade_ids():
		var def: Dictionary = SaveDataScript.UPGRADES[id]
		out.append({
			"id": id, "name": str(def.get("name", id)), "level": int(owned.get(id, 0)), "max": upgrade_max(id),
			"capped": def.has("max_level"), "unlocked": SaveDataScript.is_upgrade_unlocked(data, id),
			"description": str(def.get("description", "")),
		})
	return out

# Brings the run in progress up to date with the slot's upgrades after the debug menu wrote to them.
static func _refresh_run(main, granted_ids: Array = []) -> void:
	# a grant is applied like a purchase (so a Nest Egg also hands over its coins); any other change just re-reads the lot
	for id in granted_ids:
		main.apply_meta_purchase(str(id))
	main.apply_meta_purchase("")
	if SaveDataScript.UPGRADES.has("stamina"):
		main.player.apply_meta_purchase("stamina")

static func set_upgrade_level(main, id: String, level: int) -> Dictionary:
	if not SaveDataScript.UPGRADES.has(id):
		return fail("No such upgrade.")
	var data: Dictionary = SaveDataScript.load_data()
	if not data.has("upgrades"):
		data["upgrades"] = {}
	var before: int = int(data.upgrades.get(id, 0))
	level = clampi(level, 0, upgrade_max(id))
	if level == 0:
		data.upgrades.erase(id)
	else:
		data.upgrades[id] = level
	SaveDataScript.save_data(data)
	var granted: Array = []
	for i in maxi(0, level - before):
		granted.append(id)
	_refresh_run(main, granted)
	return ok("%s is at level %d." % [str(SaveDataScript.UPGRADES[id].get("name", id)), level])

static func grant_upgrade(main, id: String) -> Dictionary:
	return set_upgrade_level(main, id, upgrade_level(id) + 1)

static func remove_upgrade(main, id: String) -> Dictionary:
	return set_upgrade_level(main, id, upgrade_level(id) - 1)

static func max_all_upgrades(main) -> Dictionary:
	var data: Dictionary = SaveDataScript.load_data()
	data["upgrades"] = {}
	for id in upgrade_ids():
		data.upgrades[id] = upgrade_max(id)
	SaveDataScript.save_data(data)
	_refresh_run(main)
	return ok("Every Church upgrade is maxed (%d of them)." % upgrade_ids().size())

static func reset_upgrades(main) -> Dictionary:
	var data: Dictionary = SaveDataScript.load_data()
	data["upgrades"] = {}
	SaveDataScript.save_data(data)
	_refresh_run(main)
	return ok("All Church upgrades are gone (Essence kept).")

# ---------------------------------------------------------------------------------------------------------------------------
# Lifetime flags, the tutorial, the Beastiary
# ---------------------------------------------------------------------------------------------------------------------------

# The flags the game keeps for good, across every slot: always these three, plus any other true/false flag found in the file.
const KNOWN_FLAGS := [
	["tutorial_completed_ever", "First-battle tutorial done"],
	["game_completed_ever", "Game beaten once (unlocks Worldwalker)"],
	["druid_unlocked_ever", "Druid freed from the Lizen camp"],
]

static func lifetime_flags() -> Array:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	var out: Array = []
	var seen := {}
	for k in KNOWN_FLAGS:
		seen[k[0]] = true
		out.append({"key": k[0], "label": k[1], "on": bool(data.get(k[0], false))})
	for key in data:
		if seen.has(key) or typeof(data[key]) != TYPE_BOOL:
			continue
		out.append({"key": str(key), "label": str(key).replace("_", " ").capitalize(), "on": bool(data[key])})
	return out

static func set_lifetime_flag(key: String, on: bool) -> Dictionary:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	data[key] = on
	SaveDataScript.save_lifetime_data(data)
	return ok("%s: %s." % [key, "on" if on else "off"])

# The numbers the Stats screen shows, read-only.
static func lifetime_numbers() -> Array:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	var out: Array = []
	for key in data:
		if typeof(data[key]) in [TYPE_INT, TYPE_FLOAT]:
			out.append([str(key).replace("_", " ").capitalize(), int(data[key])])
	return out

static func set_tutorial_done(main, done: bool) -> Dictionary:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	data["tutorial_completed_ever"] = done
	SaveDataScript.save_lifetime_data(data)
	if done and main != null:
		main.tutorial_active = false
	return ok("The first-battle tutorial is %s." % ("done" if done else "back on for the next first battle"))

# Forgets which one-time "you found X" pop-ups have been shown, so they appear again.
static func reset_seen_unlocks() -> Dictionary:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	data["seen_unlocks"] = {}
	SaveDataScript.save_lifetime_data(data)
	return ok("The one-time pop-ups will show again.")

static func beastiary_names() -> Array:
	return HUDScript.ENEMY_ICONS.keys()

static func beastiary_seen_count() -> int:
	var n := 0
	for name in beastiary_names():
		if SaveDataScript.is_creature_seen(str(name)):
			n += 1
	return n

static func reveal_beastiary() -> Dictionary:
	for name in beastiary_names():
		SaveDataScript.mark_creature_seen(str(name))
	return ok("The Beastiary lists all %d creatures." % beastiary_names().size())

static func hide_beastiary() -> Dictionary:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	data["beastiary_seen"] = {}
	SaveDataScript.save_lifetime_data(data)
	return ok("The Beastiary is empty again.")

# ---------------------------------------------------------------------------------------------------------------------------
# Spells (the Wizard's Tower's upgrades) and the Dojo
# ---------------------------------------------------------------------------------------------------------------------------

# A spell upgrade belongs to its CASTER (a party member): this sets one member's copy of one spell.
static func set_spell_level(main, member, spell_id: String, level: int) -> Dictionary:
	if member == null or not SpellUpgradesScript.has(spell_id):
		return fail("No such spell.")
	level = clampi(level, 0, SpellUpgradesScript.MAX_LEVEL)
	main.player.set_spell_level_of(member, spell_id, level)
	return ok("%s's %s is now %s." % [str(member.name), str(SpellUpgradesScript.spell(spell_id).name), SpellUpgradesScript.display_name(spell_id, level)])

# Every spell of every member of the party.
static func set_all_spells(main, level: int) -> Dictionary:
	if main.player.party.is_empty():
		return fail("There is nobody in the party to upgrade.")
	for member in main.player.party:
		for s in SpellUpgradesScript.SPELLS:
			main.player.set_spell_level_of(member, str(s.id), level)
	return ok("Every spell of every member is at level %d." % clampi(level, 0, SpellUpgradesScript.MAX_LEVEL))

static func learn_all_specials(main) -> Dictionary:
	main.player.learn_all_specials()
	return ok("Every weapon special is learned.")

static func forget_all_specials(main) -> Dictionary:
	main.player.learned_specials = {}
	if not main.player.current_weapon_base.is_empty():
		main.player._equip_weapon(main.player.current_weapon_base)
	return ok("Every weapon special is forgotten.")

# ---------------------------------------------------------------------------------------------------------------------------
# GAME: time, collision, the slot
# ---------------------------------------------------------------------------------------------------------------------------

# Whether the menu itself has changed the game speed / the collision view (so it only ever puts back what it moved, never
# something the editor or another system set).
static var time_scale_touched := false
static var collision_view_touched := false

static func set_time_scale(scale: float) -> Dictionary:
	Engine.time_scale = clampf(scale, 0.05, 8.0)
	time_scale_touched = not is_equal_approx(Engine.time_scale, 1.0)
	return ok("Game speed x%s." % DebugActionsScript._fmt(Engine.time_scale))

# Draws every collision shape (walls, trees, hit areas): a debug view the engine has; shapes already on the map are asked to redraw.
static func set_collision_view(main, on: bool) -> Dictionary:
	var tree: SceneTree = main.get_tree()
	tree.debug_collisions_hint = on
	collision_view_touched = on
	_redraw_shapes(main)
	return ok("Collision shapes are %s." % ("drawn" if on else "hidden"))

# Gives back whatever speed / collision view the menu changed.
static func restore_engine(tree: SceneTree) -> void:
	if time_scale_touched:
		Engine.time_scale = 1.0
		time_scale_touched = false
	if collision_view_touched and tree != null:
		tree.debug_collisions_hint = false
		collision_view_touched = false

static func _redraw_shapes(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.queue_redraw()
	for c in node.get_children():
		_redraw_shapes(c)

static func collision_view_on(main) -> bool:
	return bool(main.get_tree().debug_collisions_hint)

# --- the slot's save -------------------------------------------------------------------------------------------------------

static var _memory_backup: Dictionary = {}

static func _backup_path() -> String:
	return SaveDataScript._resolve_save_path().get_basename() + "_backup.json"

static func slot_summary() -> String:
	var data: Dictionary = SaveDataScript.load_data()
	var count := 0
	for id in data.get("upgrades", {}):
		count += int(data.upgrades[id])
	var label := "Slot %d" % SaveDataScript.active_slot
	if str(data.get("name", "")) != "":
		label += " \"%s\"" % str(data.name)
	if str(data.get("difficulty", "")) != "":
		label += " · %s" % str(data.difficulty)
	else:
		label += " · no save file yet"
	return "%s · %d Essence · %d upgrade levels" % [label, int(data.get("essence", 0)), count]

static func has_backup() -> bool:
	if SaveDataScript.sandbox_active:
		return not _memory_backup.is_empty()
	return FileAccess.file_exists(_backup_path())

# Copies the slot's save (Essence, Church upgrades, name, difficulty) aside so Restore can put it back.
static func backup_slot() -> Dictionary:
	var data: Dictionary = SaveDataScript.load_data()
	if SaveDataScript.sandbox_active:
		_memory_backup = data.duplicate(true)
		return ok("Backed up the Sandbox's slot (in memory only).")
	var f := FileAccess.open(_backup_path(), FileAccess.WRITE)
	if f == null:
		return fail("Could not write the backup file.")
	f.store_string(JSON.stringify(data))
	f.close()
	return ok("Backed up slot %d." % SaveDataScript.active_slot)

static func restore_slot(main) -> Dictionary:
	var data: Dictionary = {}
	if SaveDataScript.sandbox_active:
		data = _memory_backup.duplicate(true)
	elif FileAccess.file_exists(_backup_path()):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_backup_path()))
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
	if data.is_empty():
		return fail("There is no backup to restore.")
	SaveDataScript.save_data(data)
	_refresh_run(main)
	return ok("Slot restored from the backup.")

# Wipes the slot's progress (Essence, upgrades, best) but keeps its name and difficulty. The caller asks for a confirm first.
static func reset_slot(main) -> Dictionary:
	var old: Dictionary = SaveDataScript.load_data()
	var fresh := {"essence": 0, "upgrades": {}, "best_wave": 0, "difficulty": old.get("difficulty", "normal"), "name": old.get("name", "Slot %d" % SaveDataScript.active_slot)}
	SaveDataScript.save_data(fresh)
	_refresh_run(main)
	return ok("Slot %d is reset (name and difficulty kept)." % SaveDataScript.active_slot)

# --- leaving the run -------------------------------------------------------------------------------------------------------

static func go_to_title(main) -> Dictionary:
	main.get_tree().paused = false
	Engine.time_scale = 1.0
	main.get_tree().change_scene_to_file("res://TitleScreen.tscn")
	return ok("Back to the title screen.")

# ---------------------------------------------------------------------------------------------------------------------------
# The state dump
# ---------------------------------------------------------------------------------------------------------------------------

static func state_dump(main) -> String:
	var p = main.player
	var data: Dictionary = SaveDataScript.load_data()
	var info := {
		"hero": {
			"level": p.level, "xp": "%d / %d" % [p.xp, p.xp_to_next], "hp": "%d / %d" % [p.health, p.max_health],
			"stamina": "%d / %d" % [p.stamina, p.max_stamina], "coins": p.coins, "runic_shards": p.runic_shards,
			"stats": {}, "weapon": str(p.current_weapon_base.get("id", "")), "armor": str(p.equipped_armor.get("id", "")),
			"shield": str(p.equipped_shield.get("id", "")), "clothing": p.equipped_clothing.duplicate(),
			"talismans": p.equipped_talismans.duplicate(), "difficulty": p.difficulty_id,
			"cheats": {"god": p.debug_god_mode, "infinite_stamina": p.debug_infinite_stamina, "speed_mult": p.debug_speed_mult, "one_hit_kills": DebugActionsScript.one_hit_kills_on(main)},
		},
		"owned": {
			"weapons": p.owned_weapons.keys(), "armor": p.owned_armor.keys(), "shields": p.owned_shields.keys(), "clothing": p.owned_clothing.keys(),
			"talismans": p.owned_talismans.keys(), "potions_and_food": p.potion_queue.size(), "arrows": p.owned_arrows.duplicate(), "materials": p.materials.duplicate(),
		},
		"party": [],
		"world": {
			"position": [int(p.global_position.x), int(p.global_position.y)], "region": main.current_region_id, "room": main.current_room_id,
			"in_interior": main.in_interior, "in_battle": main.in_battle, "enemies_alive": main.enemies_alive,
			"rooms_visited": main.visited_rooms.size(), "locations_found": p.discovered_locations.size(),
			"bosses_defeated": main.defeated_landmark_bosses.keys(), "kills_this_run": main.run_kills_by_name.duplicate(),
		},
		"slot": {"slot": SaveDataScript.active_slot, "sandbox": SaveDataScript.sandbox_active, "essence": int(data.get("essence", 0)), "upgrades": data.get("upgrades", {}).duplicate(), "difficulty": data.get("difficulty", "")},
		"lifetime": SaveDataScript.load_lifetime_data().duplicate(true),
		"engine": {"fps": Engine.get_frames_per_second(), "time_scale": Engine.time_scale, "paused": main.get_tree().paused},
	}
	for s in DebugActionsScript.stat_rows(main):
		info.hero.stats[s.id] = int(p.get("stat_" + s.id))
	for m in p.party:
		info.party.append({"id": m.id, "kind": m.kind, "level": m.level, "picks": m.picks, "gear": m.gear.duplicate(true)})
	for m in p.party_members:
		info.party.append({"kind": "mercenary", "name": str(m.get("name", "")), "dmg_mult": m.get("dmg_mult", 0)})
	if bool(main.in_battle):
		var units: Array = []
		for u in main.battle_units:
			units.append({"name": str(u.name), "hp": "%d / %d" % [int(u.hp), int(u.max_hp)], "tile": [u.tile.x, u.tile.y]})
		info["battle"] = {"turn": main.battle_turn, "player_tile": [main.battle_player_tile.x, main.battle_player_tile.y], "enemies": units, "allies": main.battle_allies.size(), "downed": main.battle_downed_allies.size()}
	return JSON.stringify(info, "  ")

# Prints the dump to the console (and copies it, so it can be pasted into a chat).
static func print_state(main) -> Dictionary:
	var text := state_dump(main)
	print("[Debug] ---- state dump ----\n%s\n[Debug] ---- end ----" % text)
	DisplayServer.clipboard_set(text)
	return ok("State printed to the console and copied (%d lines)." % text.count("\n"))
