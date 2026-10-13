extends SceneTree

# Ally stealth (Main.gd "Ally stealth"): EVERY roster member can use Stealth -- one extra entry in its special list, outside the
# three Party-screen slots. A hiding member cannot be picked as a target by an enemy that has not spotted it; an enemy spots it
# by coming within STEALTH_SIGHT_RANGE tiles with a clear line, or by being hit by it, and then stays on it. Its next attack
# is a guaranteed crit and ends the stealth. The Rogue's Stealth lasts longer, costs less and crits harder, and the Rogue is
# never fully visible even when not hiding (passive_sight).

const KINDS := ["druid", "guardian", "marksman", "rogue", "knight", "necromancer", "brawler", "shaman"]

func _make_goblin(main, tile: Vector2i, hp: int = 999, damage: int = 0, unit_name: String = "Goblin") -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.set_physics_process(false)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": damage,
		"name": unit_name, "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": false, "size": 1,
	}

func _reset(main, player) -> void:
	main.in_battle = true
	main.BATTLE_GRID_W = 15
	main.BATTLE_GRID_H = 15
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_downed_allies = []
	main.battle_units = []
	main.battle_actor = {}
	main.battle_commanding_ally = null
	main.battle_ally_queue = []
	main.battle_ally_target = null
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_target_index = 0
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main.battle_player_taunting = false
	main.tutorial_active = false
	main.battle_first_attack_used = true
	main.battle_fainted_members.clear()
	player.stealth_turns_remaining = 0
	player.shared_talisman_provider = Callable()
	player.miss_chance_override = 0.0
	player.max_health = 500
	player.health = 500

func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 1), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _unit(main, member, tile: Vector2i) -> Dictionary:
	var u: Dictionary = main._make_member_battle_unit(member, tile, 1.0)
	u.mods = {}
	u.weapon = {"damage_mult": 1.0}
	u.steal_chance = 0.0
	u.attack = 10.0
	return u

func _special(main, u: Dictionary, special_name: String) -> Dictionary:
	for s in main._ally_specials(u):
		if s.name == special_name:
			return s
	return {}

# The member takes its turn and casts Stealth (through the real dispatcher, paying the real cost).
func _cast_stealth(main, u: Dictionary) -> void:
	var filler := _filler()
	main.battle_commanding_ally = u
	main.battle_actor = u
	main.battle_allies = main.battle_allies.filter(func(a): return a != u and a.get("name", "") != "Filler")
	main.battle_allies.append(u)
	main.battle_allies.append(filler)
	main.battle_ally_queue = [filler]
	await main._battle_perform_attack(_special(main, u, "Stealth"))
	main.battle_actor = {}

# Would this enemy go for somebody right now (after it has had its chance to spot anyone)? (-1, -1) = nobody, it wanders.
func _target(main, g: Dictionary) -> Vector2i:
	main._update_enemy_awareness()
	return main._pick_enemy_target_tile(g)

# The member's plain attack on an adjacent fresh goblin: the damage it did.
func _swing(main, u: Dictionary) -> int:
	var g := _make_goblin(main, u.tile + Vector2i(1, 0))
	var filler := _filler()
	main.battle_allies = [u, filler]
	main.battle_ally_queue = [filler]
	main.battle_commanding_ally = u
	main.battle_actor = u
	main.battle_units = [g]
	main.battle_target_index = 0
	await main._battle_perform_attack(main._ally_regular_action(u))
	main.battle_actor = {}
	_last_goblin = g
	return 999 - int(g.hp)

var _last_goblin: Dictionary = {}

func _init() -> void:
	seed(20261013)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.max_party_slots = 20
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var members := {}
	for kind in KINDS:
		members[kind] = player.recruit(kind)
	var wolf = player.recruit("wolf")
	_reset(main, player)

	# --- everyone has it ---
	var rows := []
	for kind in KINDS:
		var u: Dictionary = _unit(main, members[kind], Vector2i(2, 2))
		var sp: Dictionary = _special(main, u, "Stealth")
		rows.append([kind, not sp.is_empty(), main._ally_cost_text(u, int(sp.get("stamina_cost", 0))).strip_edges()])
	print("Every member has Stealth in its special list, at its pool's price (20, the Rogue's 10; the Necromancer pays in HP): %s (expected [[druid, true, (20 MP)], [guardian, true, (20 STA)], [marksman, true, (20 STA)], [rogue, true, (10 STA)], [knight, true, (20 STA)], [necromancer, true, (4 HP)], [brawler, true, (20 STA)], [shaman, true, (20 MP)]])" % [rows])
	var wolf_unit: Dictionary = _unit(main, wolf, Vector2i(2, 2))
	print("The wolf, a temporary companion, does not: %s (expected {})" % [_special(main, wolf_unit, "Stealth")])
	var kn: Dictionary = _unit(main, members.knight, Vector2i(2, 2))
	var slots: int = main._ally_specials(kn).size() - 1
	print("Stealth is on top of the loadout, not one of its slots: the Knight has %d other specials (expected at most %d)" % [slots, main.PartyRulesScript.SPECIAL_SLOTS])
	print("Its menu line says what it does: '%s'" % [_special(main, kn, "Stealth").description])

	# --- casting it ---
	var cast := []
	for kind in ["knight", "rogue", "shaman", "necromancer"]:
		_reset(main, player)
		var u: Dictionary = _unit(main, members[kind], Vector2i(2, 2))
		var before: int = int(u.hp) if kind == "necromancer" else (int(u.mana) if kind == "shaman" else int(u.stamina))
		main.battle_units = [_make_goblin(main, Vector2i(9, 9))]
		await _cast_stealth(main, u)
		var after: int = int(u.hp) if kind == "necromancer" else (int(u.mana) if kind == "shaman" else int(u.stamina))
		cast.append([kind, int(u.stealth_turns), before - after])
	print("Casting it hides the member for 3 turns (the Rogue 5) and pays its price (20 STA, the Rogue's 10, 20 MP, 4 HP): %s (expected [[knight, 3, 20], [rogue, 5, 10], [shaman, 3, 20], [necromancer, 3, 4]])" % [cast])

	# --- enemies cannot pick a hiding member they have not spotted ---
	_reset(main, player)
	var hider: Dictionary = _unit(main, members.knight, Vector2i(1, 4))
	var far: Dictionary = _make_goblin(main, Vector2i(7, 4))
	main.battle_allies = [hider]
	main.battle_units = [far]
	print("An ordinary member is a target at any distance: %s (expected (1, 4))" % [_target(main, far)])
	hider.stealth_turns = 3
	print("A hiding one, 6 tiles off, is not (nor is the hero, who is far and unseen): %s (expected (-1, -1) -- the enemy wanders)" % [_target(main, far)])
	var mid: Dictionary = _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [mid]
	print("...3 tiles off is still too far (Stealth shrinks the range to 2): %s (expected (-1, -1))" % [_target(main, mid)])
	var close: Dictionary = _make_goblin(main, Vector2i(3, 4))
	main.battle_units = [close]
	print("...2 tiles off with a clear line, it is spotted: %s (expected (1, 4))" % [_target(main, close)])
	close.tile = Vector2i(9, 9)
	print("...and having spotted it the enemy keeps on it, even from far away: %s (expected (1, 4))" % [_target(main, close)])
	var behind: Dictionary = _make_goblin(main, Vector2i(3, 4))
	main.battle_terrain[Vector2i(2, 4)] = {"type": "rock", "hp": 3}
	main.battle_units = [behind]
	print("A rock between them hides it even at 2 tiles: %s (expected (-1, -1))" % [_target(main, behind)])
	main.battle_terrain.clear()
	var boss_name := ""
	for n in main.ENEMY_TRAITS:
		if main.ENEMY_TRAITS[n].get("is_boss_tier", false):
			boss_name = n
			break
	var boss: Dictionary = _make_goblin(main, Vector2i(9, 9), 999, 0, boss_name)
	main.battle_units = [boss]
	print("A boss-tier enemy (%s) sees it regardless: %s (expected (1, 4))" % [boss_name, _target(main, boss)])

	# --- a real enemy turn ---
	_reset(main, player)
	var target: Dictionary = _unit(main, members.knight, Vector2i(3, 4))
	target.stealth_turns = 3
	target.hp = 40
	target.max_hp = 40
	var biter: Dictionary = _make_goblin(main, Vector2i(9, 4), 999, 5)
	main.battle_allies = [target]
	main.battle_units = [biter]
	await main._process_enemy_turn()
	print("A goblin far away, taking its turn, does not find the hiding Knight: HP %d (expected 40)" % [target.hp])
	_reset(main, player)
	target = _unit(main, members.knight, Vector2i(3, 4))
	target.stealth_turns = 3
	target.hp = 40
	target.max_hp = 40
	biter = _make_goblin(main, Vector2i(4, 4), 999, 5)
	main.battle_allies = [target]
	main.battle_units = [biter]
	await main._process_enemy_turn()
	print("One next to him spots him and bites: HP %d (expected less than 40)" % [target.hp])

	# --- attacking ---
	_reset(main, player)
	var plain: Dictionary = _unit(main, members.knight, Vector2i(2, 2))
	var d_plain: int = await _swing(main, plain)
	var sneaky: Dictionary = _unit(main, members.knight, Vector2i(2, 2))
	sneaky.stealth_turns = 3
	var d_sneak: int = await _swing(main, sneaky)
	print("A hiding member's attack is a guaranteed crit (double) and ends the stealth: %d vs %d (expected double), stealth_turns=%d (expected 0)" % [d_sneak, d_plain, sneaky.stealth_turns])
	print("...and the enemy it hit has spotted him: %s (expected true)" % [main._enemy_sees_ally(_last_goblin, sneaky)])
	var rogue: Dictionary = _unit(main, members.rogue, Vector2i(2, 2))
	var d_rogue_plain: int = await _swing(main, rogue)
	rogue = _unit(main, members.rogue, Vector2i(2, 2))
	rogue.stealth_turns = 5
	var d_rogue_sneak: int = await _swing(main, rogue)
	print("The Rogue's stealthed crit hits for triple: %d vs %d (expected triple)" % [d_rogue_sneak, d_rogue_plain])
	var d_again: int = await _swing(main, rogue)
	print("A second swing is an ordinary hit (no more stealth): %d (expected %d)" % [d_again, d_rogue_plain])

	# --- the Rogue is never fully visible ---
	_reset(main, player)
	var rogue2: Dictionary = _unit(main, members.rogue, Vector2i(1, 4))
	main.battle_allies = [rogue2]
	var g4: Dictionary = _make_goblin(main, Vector2i(5, 4))
	main.battle_units = [g4]
	print("The Rogue, not even hiding, is not spotted from 4 tiles: %s (expected (-1, -1))" % [_target(main, g4)])
	var g3: Dictionary = _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [g3]
	print("...but is from 3 tiles: %s (expected (1, 4))" % [_target(main, g3)])
	var g3b: Dictionary = _make_goblin(main, Vector2i(4, 4))
	rogue2.stealth_turns = 5
	main.battle_units = [g3b]
	print("Hiding on top of that, 3 tiles is too far again: %s (expected (-1, -1))" % [_target(main, g3b)])

	# --- it wears off ---
	var tick := []
	var t: Dictionary = _unit(main, members.knight, Vector2i(1, 4))
	t.stealth_turns = 3
	for i in 4:
		main._tick_ally_timers(t)
		tick.append(int(t.stealth_turns))
	print("It counts down on the member's own turns and then it is gone: %s (expected [2, 1, 0, 0]); sight now %d (expected -1, visible)" % [tick, main._ally_stealth_sight(t)])
	var rg: Dictionary = _unit(main, members.rogue, Vector2i(1, 4))
	print("The Rogue's passive never wears off: sight %d (expected 3)" % [main._ally_stealth_sight(rg)])

	quit()
