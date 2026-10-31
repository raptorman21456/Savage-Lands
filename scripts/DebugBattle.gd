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
static func play_attack_style(main, command_id: String, spell_id: String = "staff_i_cast_fireball") -> Dictionary:
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
const ENEMY_STATUSES := ["poison", "burn", "bleed", "rot", "frozen", "concussed", "blind", "vulnerable", "stunned", "winding_up", "disarmed", "buffed"]

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
