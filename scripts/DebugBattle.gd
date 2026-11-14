extends RefCounted

# The Debug menu's hands, part 3: starting, ending and meddling with a tile battle. Starting one uses the same calls as
# Main.trigger_battle; ending one goes through the game's own victory / death code (_finish_enemy_actions, _battle_victory,
# Player.take_battle_damage) so XP, drops and the run's recap all happen as in a real fight. Statuses are set on the same
# fields the game's own attacks set (Main.player_poison_turns, a unit's "burning" flag...).

const DebugActionsScript := preload("res://scripts/DebugActions.gd")
const DebugWorldScript := preload("res://scripts/DebugWorld.gd")
const SandboxScript := preload("res://scripts/Sandbox.gd")
const BattleStatusesScript := preload("res://scripts/BattleStatuses.gd")
const AttackTimingsScript := preload("res://scripts/AttackTimings.gd")

# The weapon attack styles the tester offers: [command id, label, what it is].
const ATTACK_STYLES := [
	["club", "Club", "slide: a marker crosses a bar, press in the middle zone"],
	["spear", "Spear", "bullseye: a ring closes on it"],
	["greatsword", "Greatsword", "arc: the Club's bar, curved"],
	["hammer", "Hammer", "hold and release inside the zone"],
	["battle_axe", "Battle Axe", "mash: keep a falling gauge in a random band"],
	["dagger", "Dagger", "markers: random rhythm, every hit is a strike"],
	["knuckle_gloves", "Gloves", "two circles: Z and X as the rings close"],
	["hand_picks", "Picks", "round dial with a drifting zone"],
	["bow", "Bow", "crosshair: press as it crosses the centre"],
	["wand", "Wand", "trace a random shape with the mouse"],
	["staff", "Staff", "press 4-7 arrow keys in order"],
]
static func ok(msg: String, extra: Dictionary = {}) -> Dictionary:
	return DebugActionsScript.ok(msg, extra)

static func fail(msg: String) -> Dictionary:
	return DebugActionsScript.fail(msg)

static func in_battle(main) -> bool:
	return bool(main.in_battle)

# ---------------------------------------------------------------------------------------------------------------------------
# Starting a battle
# ---------------------------------------------------------------------------------------------------------------------------

# A fight against a squad of {name, count} entries (say [{"name": "Orc", "count": 2}]) at a danger tier, elite or not, with an
# extra strength multiplier and (optionally) as strong as an enemy meeting a hero of `enemy_level` (0 = the way the game scales
# it for you). The enemies stand round you, then the battle opens like any other.
static func start_battle(main, squad_spec: Array, tier: int, elite: bool, power: float = 1.0, enemy_level: int = 0) -> Dictionary:
	if bool(main.in_battle):
		return fail("A battle is already going.")
	if bool(main.choosing_stat) or bool(main.event_choosing):
		return fail("Answer the pop-up on screen first (the level-up or event choice).")
	if bool(main.game_over) or bool(main.in_interior) or bool(main.shop_open):
		return fail("Not now: close what is open and stand in the open.")
	var squad: Array = []
	var here: Vector2 = main.player.global_position
	var i := 0
	for spec in squad_spec:
		var entry: Dictionary = DebugWorldScript.enemy_entry(main, str(spec.name))
		if entry.is_empty():
			return fail("No such enemy: %s." % str(spec.name))
		for n in clampi(int(spec.get("count", 1)), 1, 12):
			var a: float = TAU * float(i) / 6.0
			squad.append(DebugWorldScript.make_enemy(main, entry, here + Vector2(cos(a), sin(a)) * 160.0, tier, elite, power, enemy_level))
			i += 1
	if squad.is_empty():
		return fail("Pick at least one enemy.")
	# the same tail as Main.trigger_battle, with the tutorial off and every enemy we made in the fight
	main.tutorial_active = false
	main.in_battle = true
	main.get_tree().paused = true
	main._setup_battle_grid(squad)
	main.hud.show_battle(main.WORLDS[main.current_world_index].battle_bg)
	main._focus_battle_main_menu()
	main._refresh_battle_display()
	main._timeline_begin()
	var names: Array = []
	for s in squad_spec:
		names.append("%d x %s" % [int(s.get("count", 1)), str(s.name)])
	return ok("Battle started: %s (danger %d)." % [", ".join(names), tier], {"close": true})

# ---------------------------------------------------------------------------------------------------------------------------
# Ending a battle
# ---------------------------------------------------------------------------------------------------------------------------

# Why the battle cannot be ended from outside right now ("" = it can): while an enemy is mid-turn the game is part-way through
# a chain of animated steps that would trip over the battle vanishing under it.
static func why_cannot_finish(main) -> String:
	if not bool(main.in_battle):
		return "There is no battle."
	if str(main.battle_turn) != "player":
		return "Wait for your turn first."
	if bool(main.battle_awaiting_evasion) or bool(main.battle_awaiting_water_confirm):
		return "Answer the question on screen first."
	return ""

# Plays one of the weapon attack popups (see ATTACK_STYLES) on its own, so you can feel it: the menu closes, the popup opens, and the
# grade it earns comes up as a message. Nothing is attacked and nothing is spent.
static func play_attack_style(main, command_id: String, spell_id: String = "staff_poison_bomb") -> Dictionary:
	var dm = main._get_attack_minigame()
	if dm._running:
		return fail("A popup is already open.")
	_play_attack_style(main, dm, command_id, spell_id)
	return ok("Opening the %s popup." % command_id.replace("_", " "), {"close": true})

static func _play_attack_style(main, dm, command_id: String, spell_id: String) -> void:
	var command: Dictionary = AttackTimingsScript.command_for(command_id)
	var opts := {}
	if command_id == "wand" or command_id == "staff":
		opts = {"verb": "CAST", "spell_id": spell_id}
	var outcome: Dictionary = await dm.run(command, opts)
	var text := "%s: %s" % [str(command.get("name", command_id)), str(outcome.get("result", "?")).to_upper()]
	if outcome.has("hits"):
		text += " (%d of %d markers)" % [int(outcome.hits), int(outcome.get("markers", 0))]
	elif outcome.has("shape"):
		text += " (%s, power x%.2f)" % [str(outcome.shape), float(outcome.get("power", 1.0))]
	main.hud.show_message(text)

# Every enemy falls (XP, drops and Essence as if you had struck them down) and the battle is won.
static func win_now(main) -> Dictionary:
	var why := why_cannot_finish(main)
	if why != "":
		return fail(why)
	var n: int = main.battle_units.size()
	for u in main.battle_units:
		u["hp"] = 0
	main.battle_commanding_ally = null
	main.battle_ally_queue.clear()
	main.battle_actor = {}
	main._finish_enemy_actions([])
	return ok("Victory: %d enemies fell." % n, {"close": true})

# Takes every enemy down to 0 HP: same as winning.
static func kill_all(main) -> Dictionary:
	return win_now(main)

# You fall: the game-over screen, as if the last blow landed. (God mode, Favour and the Phoenix are set aside for it.)
static func lose_now(main) -> Dictionary:
	var p = main.player
	if bool(main.game_over):
		return fail("The run is already over.")
	p.debug_god_mode = false
	p.second_chance_used_this_battle = true
	p.phoenix_used = true
	p.take_battle_damage(p.health + 1000)
	return ok("You fell.", {"close": true})

# Everyone on your side to full: you, and every ally (the downed stand up).
static func heal_everyone(main) -> Dictionary:
	var p = main.player
	p.restore_health(p.max_health)
	p.reset_stamina()
	var text := "You are at full HP and stamina."
	if bool(main.in_battle):
		for a in main.battle_downed_allies.duplicate():
			main._revive_downed(a, 1.0)
		for a in main.battle_allies:
			a["hp"] = int(a.max_hp)
			if a.has("max_stamina"):
				a["stamina"] = int(a.max_stamina)
			if a.has("max_mana"):
				a["mana"] = int(a.max_mana)
		main._refresh_battle_display()
		text = "Everyone is at full health and resources."
	return ok(text)

# Gives the current turn back: full movement, and your turn restarts from the top menu.
static func refill_turn(main) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	main.battle_player_moves_left = main._battle_player_move_range()
	main.player.reset_stamina()
	main._refresh_battle_display()
	return ok("Movement and stamina are back.")

# ---------------------------------------------------------------------------------------------------------------------------
# Statuses
# ---------------------------------------------------------------------------------------------------------------------------

# What can be put on each kind of target: [[id, label], ...] (labels are BattleStatuses' names).
const HERO_STATUSES := ["poison", "burn", "bleed", "blind", "concussed", "disarmed", "stealth", "berserk", "buffed", "bloodrage",
	"potion_attack", "potion_resilience", "potion_energy", "skip", "defending", "taunting", "bloodboost", "bloodcrash"]
const ALLY_STATUSES := ["stealth", "defending", "buffed", "charm", "bloodrage", "skip", "disarmed"]
const ENEMY_STATUSES := ["poison", "burn", "bleed", "rot", "frozen", "concussed", "blind", "vulnerable", "stunned", "fear", "winding_up", "disarmed", "buffed"]

static func status_name(id: String) -> String:
	return str(BattleStatusesScript.TEXT.get(id, [id.capitalize()])[0])

static func status_desc(id: String) -> String:
	var t: Array = BattleStatusesScript.TEXT.get(id, [])
	return str(t[1]) if t.size() > 1 else ""

static func statuses_for(kind: String) -> Array:
	match kind:
		"hero": return HERO_STATUSES
		"ally", "all_allies": return ALLY_STATUSES
	return ENEMY_STATUSES

# The targets on the field right now: [{id: "hero"|"ally:0"|"enemy:1"|"all_enemies"|"all_allies", label, kind}].
static func targets(main) -> Array:
	var out: Array = [{"id": "hero", "label": "You", "kind": "hero"}]
	for i in main.battle_allies.size():
		out.append({"id": "ally:%d" % i, "label": str(main.battle_allies[i].get("name", "Ally")), "kind": "ally"})
	for i in main.battle_units.size():
		out.append({"id": "enemy:%d" % i, "label": "%s %d" % [str(main.battle_units[i].get("name", "Enemy")), i + 1], "kind": "enemy"})
	if not main.battle_allies.is_empty():
		out.append({"id": "all_allies", "label": "All allies", "kind": "all_allies"})
	if not main.battle_units.is_empty():
		out.append({"id": "all_enemies", "label": "All enemies", "kind": "enemy"})
	return out

# Puts a status on a target (or takes it off: turns <= 0 and `remove`).
static func set_status(main, target_id: String, status_id: String, turns: int, remove: bool = false) -> Dictionary:
	if not bool(main.in_battle):
		return fail("Statuses live on the battle grid: start a battle first.")
	var label := ""
	if target_id == "hero":
		_hero_status(main, status_id, turns, remove)
		label = "you"
	elif target_id == "all_enemies":
		for u in main.battle_units:
			_enemy_status(main, u, status_id, turns, remove)
		label = "all enemies"
	elif target_id == "all_allies":
		for a in main.battle_allies:
			_ally_status(main, a, status_id, turns, remove)
		label = "all allies"
	elif target_id.begins_with("ally:"):
		var ai: int = int(target_id.get_slice(":", 1))
		if ai < 0 or ai >= main.battle_allies.size():
			return fail("That ally is gone.")
		_ally_status(main, main.battle_allies[ai], status_id, turns, remove)
		label = str(main.battle_allies[ai].get("name", "the ally"))
	elif target_id.begins_with("enemy:"):
		var ei: int = int(target_id.get_slice(":", 1))
		if ei < 0 or ei >= main.battle_units.size():
			return fail("That enemy is gone.")
		_enemy_status(main, main.battle_units[ei], status_id, turns, remove)
		label = str(main.battle_units[ei].get("name", "the enemy"))
	else:
		return fail("No such target.")
	main._refresh_battle_display()
	if remove:
		return ok("%s taken off %s." % [status_name(status_id), label])
	return ok("%s put on %s%s." % [status_name(status_id), label, " for %d turns" % turns if turns > 0 else ""])

static func _hero_status(main, id: String, turns: int, remove: bool) -> void:
	var p = main.player
	var t: int = 0 if remove else maxi(1, turns)
	var flag: bool = not remove
	match id:
		"poison":
			main.player_poison_turns = t
			main.player_poison_dmg = maxi(1, int(round(p.max_health * main.POISON_DAMAGE_PCT))) if not remove else 0
		"burn": main.player_burning = flag
		"bleed": main.player_bleed_turns = t
		"blind": main.player_blind_turns = t
		"concussed": main.player_concussed_turns = t
		"disarmed": p.disarmed_tile = Vector2i(-1, -1) if remove else main._pick_disarm_tile()
		"stealth": p.stealth_turns_remaining = t
		"berserk": p.berserk_turns_remaining = t
		"buffed": main.battle_hero_buff_turns = t
		"bloodrage":
			main.battle_bloodrage_stacks = t
			main.battle_bloodrage_turns = 0 if remove else 2
		"potion_attack": p.potion_attack_turns = t
		"potion_resilience": p.potion_resilience_turns = t
		"potion_energy": p.potion_energy_turns = t
		"skip": main.battle_player_turns_to_skip = t
		"defending": main.battle_player_defending = flag
		"taunting": main.battle_player_taunting = flag
		"bloodboost": p.bloodmoon_stacks = mini(t, p.BLOODMOON_MAX_STACKS)
		"bloodcrash": p.bloodmoon_debuffed = flag

static func _ally_status(main, a: Dictionary, id: String, turns: int, remove: bool) -> void:
	var t: int = 0 if remove else maxi(1, turns)
	match id:
		"stealth": a["stealth_turns"] = t
		"defending": a["defending"] = not remove
		"buffed": a["buff_turns"] = t
		"charm": a["charm_turns"] = t
		"bloodrage": a["bloodrage_stacks"] = t
		"skip": a["skip_turns"] = t
		"disarmed": a["disarmed_tile"] = Vector2i(-1, -1) if remove else main._pick_disarm_tile()

static func _enemy_status(main, u: Dictionary, id: String, turns: int, remove: bool) -> void:
	var t: int = 0 if remove else maxi(1, turns)
	match id:
		"poison":
			u["poison_turns"] = t
			u["poison_dmg"] = maxi(1, int(round(float(u.max_hp) * main.POISON_DAMAGE_PCT)))
		"burn": u["burning"] = not remove
		"bleed": u["bleed_turns"] = t
		"rot":
			u["rot_turns"] = t
			u["rot_pct"] = 0.1
		"frozen": u["frozen_turns"] = t
		"concussed": u["concussed_turns"] = t
		"blind": u["blind_turns"] = t
		"vulnerable": u["vulnerable_turns"] = t
		"stunned": u["stunned"] = not remove
		"fear": u["fear_turns"] = t
		"winding_up": u["winding_up"] = not remove
		"disarmed": u["disarmed_tile"] = Vector2i(-1, -1) if remove else main._pick_disarm_tile()
		"buffed":
			u["buffed_dmg_turns"] = t
			u["buffed_dmg_pct"] = main.DRUID_BUFF_DMG_PCT

# Wipes every status off a target.
static func clear_statuses(main, target_id: String) -> Dictionary:
	var kind := "hero" if target_id == "hero" else ("all_enemies" if target_id in ["all_enemies"] or target_id.begins_with("enemy:") else "ally")
	var ids: Array = HERO_STATUSES if kind == "hero" else (ENEMY_STATUSES if kind == "all_enemies" else ALLY_STATUSES)
	for id in ids:
		var r := set_status(main, target_id, str(id), 0, true)
		if not bool(r.ok) and not bool(main.in_battle):
			return r
	return ok("All statuses cleared.")

# A readable list of what a target has right now.
static func status_list(main, target_id: String) -> Array:
	if not bool(main.in_battle):
		return []
	if target_id == "hero":
		return BattleStatusesScript.for_hero(main._hero_status_state())
	if target_id.begins_with("ally:"):
		var ai: int = int(target_id.get_slice(":", 1))
		return BattleStatusesScript.for_ally(main.battle_allies[ai]) if ai < main.battle_allies.size() else []
	if target_id.begins_with("enemy:"):
		var ei: int = int(target_id.get_slice(":", 1))
		return BattleStatusesScript.for_enemy(main.battle_units[ei]) if ei < main.battle_units.size() else []
	return []

# Takes one enemy to 0 HP (the last one ends the battle in your favour).
static func kill_enemy(main, index: int) -> Dictionary:
	var why := why_cannot_finish(main)
	if why != "":
		return fail(why)
	if index < 0 or index >= main.battle_units.size():
		return fail("That enemy is gone.")
	var label: String = str(main.battle_units[index].name)
	main.battle_units[index]["hp"] = 0
	main._finish_enemy_actions([])
	return ok("The %s fell." % label)

# Sets an enemy's HP (1 up to its max).
static func set_enemy_hp(main, index: int, hp: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	if index < 0 or index >= main.battle_units.size():
		return fail("That enemy is gone.")
	var u: Dictionary = main.battle_units[index]
	u["hp"] = clampi(hp, 1, int(u.max_hp))
	main._refresh_battle_display()
	return ok("The %s has %d / %d HP." % [str(u.name), int(u.hp), int(u.max_hp)])

# ---------------------------------------------------------------------------------------------------------------------------
# More control over a fight in progress: your turn, anyone's HP, allies down and up, units added and moved, the ground, the counters
# ---------------------------------------------------------------------------------------------------------------------------

const BASE_TERRAIN := ["rock", "water", "ledge", "cliff"]

static func terrain_types(main) -> Array:
	return BASE_TERRAIN + main.RESERVED_TERRAIN_TYPES

# --- cheats that only matter in a fight ---
static func set_always_crit(main, on: bool) -> Dictionary:
	main.player.debug_always_crit = on
	return ok("Every hit you or your party lands is a critical hit: %s." % ("on" if on else "off"))

static func set_enemies_pass(main, on: bool) -> Dictionary:
	main.player.debug_enemies_pass = on
	return ok("Enemies %s on their turns." % ("stand still" if on else "act"))

# Your attacks and your party's never miss (the miss chance is replaced by none); off puts the real chances back.
static func set_never_miss(main, on: bool) -> Dictionary:
	main.player.miss_chance_override = 0.0 if on else (0.0 if OS.get_cmdline_args().has("--script") else -1.0)
	return ok("Attacks never miss: %s." % ("on" if on else "off"))

static func never_miss_on(main) -> bool:
	return main.player.miss_chance_override == 0.0

# --- your turn ---
# Ends your turn as if you had pressed it (statuses tick, then the others act).
static func end_my_turn(main) -> Dictionary:
	var why := why_cannot_finish(main)
	if why != "":
		return fail(why)
	if main.battle_commanding_ally != null:
		return fail("An ally is in the middle of its turn: finish that first.")
	main._end_player_turn()
	return ok("Your turn ends.", {"close": true})

static func set_moves_left(main, tiles: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	main.battle_player_moves_left = maxi(0, tiles)
	main._refresh_battle_display()
	return ok("You can move %d more tile%s this turn." % [main.battle_player_moves_left, "" if main.battle_player_moves_left == 1 else "s"])

# The fight's counters: the kills towards your next Berserk, and Momentum stacks.
static func set_berserk_kills(main, n: int) -> Dictionary:
	main.player.berserk_kills = maxi(0, n)
	if bool(main.in_battle):
		main._refresh_battle_display()
	return ok("%d kill%s counted towards Berserk." % [main.player.berserk_kills, "" if main.player.berserk_kills == 1 else "s"])

static func set_momentum(main, n: int) -> Dictionary:
	main.battle_momentum_stacks = maxi(0, n)
	if bool(main.in_battle):
		main._refresh_battle_display()
	return ok("Momentum x%d." % main.battle_momentum_stacks)

# --- anyone's HP ---
# Sets the HP of you ("hero"), an ally ("ally:0") or an enemy ("enemy:1"): 1 up to its max (use Kill / Down to take it to 0).
static func set_unit_hp(main, target_id: String, hp: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	if target_id == "hero":
		return DebugActionsScript.set_health(main, hp)
	if target_id.begins_with("ally:"):
		var ai: int = int(target_id.get_slice(":", 1))
		if ai < 0 or ai >= main.battle_allies.size():
			return fail("That ally is gone.")
		var a: Dictionary = main.battle_allies[ai]
		a["hp"] = clampi(hp, 1, int(a.max_hp))
		main._refresh_battle_display()
		return ok("%s has %d / %d HP." % [str(a.get("name", "The ally")), int(a.hp), int(a.max_hp)])
	if target_id.begins_with("enemy:"):
		return set_enemy_hp(main, int(target_id.get_slice(":", 1)), hp)
	return fail("No such target.")

# An ally's mana or stamina (whichever pool it has), 0 up to its max.
static func set_ally_pool(main, index: int, pool: String, value: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	if index < 0 or index >= main.battle_allies.size():
		return fail("That ally is gone.")
	var a: Dictionary = main.battle_allies[index]
	if not a.has(pool) or int(a.get("max_%s" % pool, 0)) <= 0:
		return fail("%s has no %s." % [str(a.get("name", "That ally")), pool])
	a[pool] = clampi(value, 0, int(a["max_%s" % pool]))
	main._refresh_battle_display()
	return ok("%s has %d / %d %s." % [str(a.get("name", "The ally")), int(a[pool]), int(a["max_%s" % pool]), pool])

# Knocks an ally down (HP 0: the game's own downing, so they can be revived).
static func down_ally(main, index: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	if index < 0 or index >= main.battle_allies.size():
		return fail("That ally is gone.")
	var a: Dictionary = main.battle_allies[index]
	var label := str(a.get("name", "The ally"))
	a["hp"] = 0
	main._remove_fallen_allies()
	main._refresh_battle_display()
	return ok("%s is down." % label)

# Stands a downed ally back up at full HP.
static func revive_ally(main, downed_index: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	if downed_index < 0 or downed_index >= main.battle_downed_allies.size():
		return fail("Nobody is down there.")
	var a: Dictionary = main.battle_downed_allies[downed_index]
	var label := str(a.get("name", "The ally"))
	main._revive_downed(a, 1.0)
	main._refresh_battle_display()
	return ok("%s is back on their feet." % label)

# --- adding to the fight ---
# Every tile of the grid a unit of `size` could stand on (its whole footprint free: no unit, no terrain), nearest to `prefer` first.
static func free_tiles(main, size: int, prefer: Vector2i) -> Array:
	var taken := {}
	taken[main.battle_player_tile] = true
	for a in main.battle_allies:
		taken[a.tile] = true
	for u in main.battle_units:
		for cell in main._footprint(u.tile, int(u.get("size", 1))):
			taken[cell] = true
	var out: Array = []
	for x in main.BATTLE_GRID_W:
		for y in main.BATTLE_GRID_H:
			var t := Vector2i(x, y)
			var fits := true
			for cell in main._footprint(t, size):
				if cell.x < 0 or cell.y < 0 or cell.x >= main.BATTLE_GRID_W or cell.y >= main.BATTLE_GRID_H or taken.has(cell) or main.battle_terrain.has(cell):
					fits = false
					break
			if fits:
				out.append(t)
	out.sort_custom(func(a, b): return (a - prefer).length_squared() < (b - prefer).length_squared())
	return out

# The battle unit for an enemy node, the way Main._setup_battle_grid makes one (level, danger, difficulty, elite, power, early-game bonus).
static func battle_unit_for(main, e) -> Dictionary:
	var display_name: String = e.get_display_name()
	var traits: Dictionary = main.ENEMY_TRAITS.get(display_name, {})
	var boss: bool = bool(traits.get("is_boss_tier", false))
	var scale_mult: float = main._enemy_level_scale(boss) * float(e.get_meta("region_tier_power", 1.0))
	var early_hp: float = main._early_hp_factor(boss, traits)
	var elite_hp: float = main.ELITE_HP_MULT if e.is_elite else 1.0
	var elite_dmg: float = main.ELITE_DAMAGE_MULT if e.is_elite else 1.0
	var power_raw = e.get("power_tier")
	if e.has_meta("sandbox_power_tier"):
		power_raw = e.get_meta("sandbox_power_tier")
	var power: float = power_raw if power_raw != null else 1.0
	var hp: int = maxi(1, int(round(e.MAX_HEALTH * scale_mult * elite_hp * main.player.difficulty_mult * power * early_hp)))
	var dmg: int = maxi(1, int(round(e.get_contact_damage() * scale_mult * main._enemy_damage_mult(e, boss) * elite_dmg * main.player.difficulty_mult * power)))
	return {
		"ref": e, "tile": Vector2i.ZERO, "hp": hp, "max_hp": hp, "move_range": traits.get("move_range", 2), "damage": dmg,
		"name": display_name, "winding_up": false, "stunned": false, "size": traits.get("size", 1),
		"attack_range": traits.get("attack_range", 1), "is_elite": e.is_elite,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "vulnerable_turns": 0, "aware_of_player": false,
		"armored": traits.get("armored", false), "disarmed_tile": Vector2i(-1, -1),
	}

# Puts `count` more of an enemy into the running fight (on the far side, wherever there is room).
static func add_enemy(main, enemy_name: String, count: int, tier: int, elite: bool, power: float = 1.0, enemy_level: int = 0) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle. Start one first.")
	var entry: Dictionary = DebugWorldScript.enemy_entry(main, enemy_name)
	if entry.is_empty():
		return fail("No such enemy: %s." % enemy_name)
	var added := 0
	for i in clampi(count, 1, 12):
		var node = DebugWorldScript.make_enemy(main, entry, main.player.global_position, tier, elite, power, enemy_level)
		var unit: Dictionary = battle_unit_for(main, node)
		var spots: Array = free_tiles(main, int(unit.size), Vector2i(main.BATTLE_GRID_W - 2, main.BATTLE_GRID_H / 2))
		if spots.is_empty():
			main.enemies_alive -= 1
			node.queue_free()
			break
		unit["tile"] = spots[0]
		main.battle_units.append(unit)
		added += 1
	if added == 0:
		return fail("There is no room on the grid.")
	main._timeline_sync()
	main._refresh_battle_display()
	return ok("%d x %s joined the fight." % [added, enemy_name])

# A brand-new party member of `kind`, recruited (the party's size limit is raised if it must be) and put straight onto the grid.
static func add_ally(main, kind: String) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle. Start one first.")
	var p = main.player
	var guard := 0
	while not p.can_recruit(kind) and guard < 40:
		p.max_party_slots += 1
		guard += 1
	var member = p.recruit(kind)
	if member == null:
		return fail("Could not recruit %s." % kind)
	var spots: Array = free_tiles(main, 1, main.battle_player_tile)
	if spots.is_empty():
		p.dismiss_party_member(member.id)
		return fail("There is no room on the grid.")
	var unit: Dictionary = main._make_member_battle_unit(member, spots[0], 1.0 + p.stat_might * main.MIGHT_ALLY_DAMAGE_PCT_PER_POINT)
	main.battle_allies.append(unit)
	main._timeline_sync()
	main._refresh_battle_display()
	return ok("%s joined the fight." % str(member.name))

# --- moving things ---
# Puts you ("hero"), an ally or an enemy on a tile (a whole footprint for a big enemy); the tile must be free of other units and terrain.
static func move_unit(main, target_id: String, x: int, y: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	var tile := Vector2i(x, y)
	var size := 1
	var holder = null
	var label := "You"
	if target_id.begins_with("ally:"):
		var ai: int = int(target_id.get_slice(":", 1))
		if ai < 0 or ai >= main.battle_allies.size():
			return fail("That ally is gone.")
		holder = main.battle_allies[ai]
		label = str(holder.get("name", "The ally"))
	elif target_id.begins_with("enemy:"):
		var ei: int = int(target_id.get_slice(":", 1))
		if ei < 0 or ei >= main.battle_units.size():
			return fail("That enemy is gone.")
		holder = main.battle_units[ei]
		size = int(holder.get("size", 1))
		label = str(holder.get("name", "The enemy"))
	elif target_id != "hero":
		return fail("No such target.")
	# the tile has to be free for everybody but the one moving: take it off the board first, then look
	var old_tile: Vector2i = main.battle_player_tile if holder == null else holder.tile
	if holder == null:
		main.battle_player_tile = Vector2i(-100, -100)
	else:
		holder["tile"] = Vector2i(-100, -100)
	var spots: Array = free_tiles(main, size, tile)
	var free: bool = not spots.is_empty() and spots.has(tile)
	if holder == null:
		main.battle_player_tile = tile if free else old_tile
	else:
		holder["tile"] = tile if free else old_tile
	if not free:
		return fail("(%d, %d) is not free: it is off the grid, occupied, or has terrain on it." % [x, y])
	main._refresh_battle_display()
	return ok("%s moved to (%d, %d)." % [label, x, y])

# --- the ground ---
static func set_terrain(main, x: int, y: int, kind: String) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	if not terrain_types(main).has(kind):
		return fail("No such terrain: %s." % kind)
	var tile := Vector2i(x, y)
	if x < 0 or y < 0 or x >= main.BATTLE_GRID_W or y >= main.BATTLE_GRID_H:
		return fail("(%d, %d) is off the grid (%d x %d)." % [x, y, main.BATTLE_GRID_W, main.BATTLE_GRID_H])
	var occupied: bool = tile == main.battle_player_tile
	for a in main.battle_allies:
		occupied = occupied or a.tile == tile
	for u in main.battle_units:
		occupied = occupied or main._footprint(u.tile, int(u.get("size", 1))).has(tile)
	if occupied:
		return fail("Somebody is standing on (%d, %d)." % [x, y])
	var entry := {"type": kind}
	if kind == "water":
		entry["push_dir"] = main.CARDINAL_DIRS[0]
	if kind == "ledge" or kind == "cliff":
		entry["dir"] = main.CARDINAL_DIRS[0]
	main.battle_terrain[tile] = entry
	main._refresh_battle_display()
	return ok("%s at (%d, %d)." % [kind.capitalize().replace("_", " "), x, y])

static func clear_terrain(main, x: int, y: int) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	var tile := Vector2i(x, y)
	if not main.battle_terrain.has(tile):
		return fail("There is nothing on (%d, %d)." % [x, y])
	main.battle_terrain.erase(tile)
	main._refresh_battle_display()
	return ok("(%d, %d) is bare ground." % [x, y])

static func clear_all_terrain(main) -> Dictionary:
	if not bool(main.in_battle):
		return fail("There is no battle.")
	var n: int = main.battle_terrain.size()
	main.battle_terrain.clear()
	main._refresh_battle_display()
	return ok("%d tile%s cleared." % [n, "" if n == 1 else "s"])
