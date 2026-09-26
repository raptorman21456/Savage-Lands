extends SceneTree

# Off-hand shield slot: 5 distinct shields (Shields.gd), only active while
# wielding one of Shields.COMPATIBLE_WEAPONS, each with a passive block
# chance (flat -- identical off-synergy, independent of Defend), a damage
# penalty for fighting one-handed (every shield except the free Wooden
# Buckler), plus a special ability (knockback/thorns/evasive/vengeance) that
# fires only when that passive block succeeds (evasive is the exception --
# see below).

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 3, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var shields_script = load("res://scripts/Shields.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# --- Data sanity: 5 distinct shields, all restricted to the same 5
	# one-handed weapon types. ---
	print("Shields.SHIELD_IDS has exactly 5 entries: %d (expected 5)" % [shields_script.SHIELD_IDS.size()])
	print("Compatible weapons match the 5 the user asked for: %s (expected true)" % [
		shields_script.COMPATIBLE_WEAPONS == ["club", "spear", "hammer", "dagger", "knuckle_gloves"]
	])
	print("Greatsword/Battle Axe/Bow/Hand Picks are NOT shield-compatible: %s (expected true)" % [
		not shields_script.is_weapon_compatible("greatsword") and not shields_script.is_weapon_compatible("battle_axe")
		and not shields_script.is_weapon_compatible("bow") and not shields_script.is_weapon_compatible("hand_picks")
	])

	# =========================================================
	# Buy / equip (Player.gd)
	# =========================================================
	player.coins = 1000
	player.owned_shields = {}
	player.equipped_shield = {}
	var buckler: Dictionary = shields_script.SHIELDS.shield_buckler
	var bought: bool = player.try_buy_shield(buckler)
	print("Buying a shield deducts its price and equips it: bought=%s coins=%d (expected true, %d), equipped=%s (expected Wooden Buckler)" % [
		bought, player.coins, 1000 - buckler.price, player.equipped_shield.get("name", "")
	])
	print("...and marks it owned: %s (expected true)" % [player.owned_shields.has("shield_buckler")])

	# Re-selecting an already-owned shield is free -- just re-equips, same
	# pattern as try_buy_armor/try_buy_weapon.
	var heavy: Dictionary = shields_script.SHIELDS.shield_heavy
	player.try_buy_shield(heavy)
	var coins_after_first_two: int = player.coins
	var reequip_ok: bool = player.try_buy_shield(buckler)
	print("Re-equipping an already-owned shield doesn't charge again: ok=%s coins_unchanged=%s (expected true, true)" % [
		reequip_ok, player.coins == coins_after_first_two
	])
	print("...and actually swaps the equipped shield back: %s (expected Wooden Buckler)" % [player.equipped_shield.get("name", "")])

	# Can't afford: refuses cleanly, no partial state change.
	player.owned_shields = {}
	player.equipped_shield = {}
	player.coins = 0
	var bulwark: Dictionary = shields_script.SHIELDS.shield_bulwark
	var cant_afford: bool = player.try_buy_shield(bulwark)
	print("Can't afford a shield: bought=%s owned=%s (expected false, false)" % [cant_afford, player.owned_shields.has("shield_bulwark")])
	player.coins = 1000

	# =========================================================
	# shield_block_chance() / shield_push_immune() / shield_special_pct():
	# flat block chance regardless of synergy (a shield "can be used with
	# weapons other than their synergies" at full protection), inert with
	# nothing equipped or on an incompatible weapon, and carried gear stays
	# OWNED even while inert.
	# =========================================================
	player.equipped_shield = {}
	player.current_weapon = weapons_script.CLUB
	print("No shield equipped: block_chance=%.2f (expected 0.0)" % [player.shield_block_chance()])

	player.try_buy_shield(heavy)  # synergy_weapon: spear
	player.current_weapon = weapons_script.CLUB
	print("Heavy Shield's block chance is identical off its synergy weapon (Club): block_chance=%.2f (expected %.2f)" % [
		player.shield_block_chance(), heavy.block_chance
	])
	player.current_weapon = weapons_script.SPEAR
	print("...and unchanged ON its synergy weapon too -- block chance never varies by weapon: block_chance=%.2f (expected %.2f)" % [
		player.shield_block_chance(), heavy.block_chance
	])
	print("...only the special's own power scales with synergy: %.2f (expected %.2f, synergy_special_pct)" % [player.shield_special_pct(), heavy.synergy_special_pct])
	print("Heavy Shield's push immunity is active on its synergy weapon: %s (expected true)" % [player.shield_push_immune()])

	player.current_weapon = weapons_script.GREATSWORD
	print("A shield goes fully inert on an incompatible weapon (Greatsword): block_chance=%.2f push_immune=%s (expected 0.0, false)" % [
		player.shield_block_chance(), player.shield_push_immune()
	])
	print("...but stays owned/equipped regardless -- it's just inert, not unequipped: owned=%s equipped_name=%s (expected true, Heavy Shield)" % [
		player.owned_shields.has("shield_heavy"), player.equipped_shield.get("name", "")
	])
	player.current_weapon = weapons_script.CLUB

	# =========================================================
	# Skill tree: Shield Mastery (flat block-chance bonus) / Unbreakable
	# Guard (waives the weapon-compat gate entirely) -- SaveData.gd
	# UPGRADES/Player.gd meta_shield_block_bonus_pct/meta_shield_universal.
	# =========================================================
	player.meta_shield_block_bonus_pct = 0.0
	player.meta_shield_universal = false
	player.current_weapon = weapons_script.CLUB
	print("Shield Mastery adds a flat bonus on top of the shield's own rate: %.2f (expected %.2f)" % [
		player.shield_block_chance(), heavy.block_chance
	])
	player.meta_shield_block_bonus_pct = 0.24
	print("...with Shield Mastery maxed (+24%%): %.2f (expected %.2f)" % [
		player.shield_block_chance(), heavy.block_chance + 0.24
	])
	player.meta_shield_block_bonus_pct = 0.0

	player.current_weapon = weapons_script.GREATSWORD
	print("Without Unbreakable Guard, an incompatible weapon still goes fully inert: block_chance=%.2f push_immune=%s (expected 0.0, false)" % [
		player.shield_block_chance(), player.shield_push_immune()
	])
	player.meta_shield_universal = true
	print("Unbreakable Guard keeps the shield fully active on a two-handed weapon: block_chance=%.2f push_immune=%s (expected %.2f, true)" % [
		player.shield_block_chance(), player.shield_push_immune(), heavy.block_chance
	])
	var phantom_guard: Dictionary = shields_script.SHIELDS.shield_phantom
	player.try_buy_shield(phantom_guard)
	print("...and also revives Evasion on an otherwise-incompatible weapon: %s (expected true)" % [player.shield_evasion_active()])
	player.meta_shield_universal = false
	player.try_buy_shield(heavy)
	player.current_weapon = weapons_script.CLUB

	# =========================================================
	# Battle mechanics
	# =========================================================
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_target_index = 0
	player.equipped_armor = {"damage_reduction": 0.0}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_dodge_chance = 0.0
	player.meta_riposte_chance = 0.0
	player.meta_block_negate_chance = 0.0
	player.max_health = 100
	player.health = 100
	player.attack_damage = 10
	player.current_weapon = weapons_script.CLUB

	# --- Wooden Buckler: a passive block is NOT gated on Defending, unlike
	# Block Master -- the key thing that separates a shield from that skill. ---
	player.owned_shields = {}
	player.equipped_shield = {}
	player.try_buy_shield(buckler)
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 1.0
	main.battle_player_defending = false
	var block_result: Dictionary = main._enemy_apply_damage({"tile": Vector2i(4, 5), "name": "Goblin"}, main.battle_player_tile, 50, {})
	print("A shield's block roll fires even without Defending: dmg=%d blocked=%s (expected 0, true), health_unchanged=%s (expected true)" % [
		block_result.dmg, block_result.get("blocked", false), player.health == 100
	])

	# --- Heavy Shield "knockback": a successful block shoves the attacker
	# back a tile (bypass_resist=true -- Heavy Shield's whole point is that
	# it always lands), two tiles with its synergy weapon (Spear). ---
	player.owned_shields = {}
	player.equipped_shield = {}
	player.try_buy_shield(heavy)
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 1.0
	player.current_weapon = weapons_script.CLUB
	var g_knock_1 := _make_goblin(main, Vector2i(4, 5), 999)
	main.battle_units = [g_knock_1]
	main._enemy_apply_damage(g_knock_1, main.battle_player_tile, 50, {})
	print("Heavy Shield's knockback shoves the attacker back one tile off-synergy: %s (expected (4, 6))" % [g_knock_1.tile])

	player.current_weapon = weapons_script.SPEAR
	var g_knock_2 := _make_goblin(main, Vector2i(4, 5), 999)
	main.battle_units = [g_knock_2]
	main._enemy_apply_damage(g_knock_2, main.battle_player_tile, 50, {})
	print("...and two tiles with its synergy weapon (Spear): %s (expected (4, 7))" % [g_knock_2.tile])
	player.current_weapon = weapons_script.CLUB

	# --- Heavy Shield "push_immune": the player can't be pushed by water at
	# the end of their turn while it's raised. ---
	main.battle_terrain[main.battle_player_tile] = {"type": "water", "push_dir": Vector2i(1, 0)}
	main.battle_skill_cooldown = 0
	var pos_before_push: Vector2i = main.battle_player_tile
	main._end_player_turn()
	print("Heavy Shield's passive blocks the water push: player_tile=%s (expected unchanged %s)" % [main.battle_player_tile, pos_before_push])
	main.battle_terrain.clear()
	main.in_battle = true
	main.battle_turn = "enemy"

	# --- Iron Bulwark "thorns": reflects a % of the blocked hit's raw damage
	# back at the attacker. ---
	player.owned_shields = {}
	player.equipped_shield = {}
	player.try_buy_shield(bulwark)
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 1.0
	var g_thorns := _make_goblin(main, Vector2i(4, 5), 999)
	main.battle_units = [g_thorns]
	main._enemy_apply_damage(g_thorns, main.battle_player_tile, 40, {})
	var expected_thorns_dmg: int = int(round(40 * player.shield_special_pct()))
	print("Iron Bulwark's thorns reflect a %% of the raw hit back: dealt=%d (expected %d)" % [999 - g_thorns.hp, expected_thorns_dmg])

	# --- Phantom Guard "evasive": a dodge pauses the attacker's turn (the
	# only mid-resolution await in the whole turn cycle -- see
	# _prompt_evasion_reposition's doc comment) so the player can dodge-roll
	# exactly one tile: back, left, or right relative to the attacker. Fired
	# WITHOUT await here on purpose: it runs synchronously up to the await
	# point and suspends there, which we can observe directly via
	# battle_awaiting_evasion. Attacker at (4,5), player at (4,4) -- straight
	# back is (0,-1), so left/right resolve to (1,0)/(-1,0). ---
	var phantom: Dictionary = shields_script.SHIELDS.shield_phantom
	player.owned_shields = {}
	player.equipped_shield = {}
	player.try_buy_shield(phantom)
	player.meta_dodge_chance = 1.0
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_terrain.clear()
	main.battle_units = []
	main._enemy_apply_damage({"tile": Vector2i(4, 5), "name": "Goblin"}, main.battle_player_tile, 50, {})
	print("Evasion pauses the attacker's turn: battle_awaiting_evasion=%s (expected true)" % [main.battle_awaiting_evasion])
	print("...offering all 3 directions when nothing blocks them: %s (expected {back:(0,-1), left:(1,0), right:(-1,0)})" % [main.battle_evasion_options])

	var pos_before_evade: Vector2i = main.battle_player_tile
	main.evasion_direction_chosen.emit(main.battle_evasion_options["right"])
	print("Choosing a direction relocates the player: %s (expected %s)" % [main.battle_player_tile, pos_before_evade + Vector2i(-1, 0)])
	print("...and ends the prompt immediately, no separate Confirm: battle_awaiting_evasion=%s (expected false)" % [main.battle_awaiting_evasion])

	# --- Restriction: a direction that isn't actually a free tile (blocked
	# here by a rock where "back" would land) is left out of the offer
	# entirely, while the other two remain available. ---
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(4, 3)] = {"type": "rock"}
	main._enemy_apply_damage({"tile": Vector2i(4, 5), "name": "Goblin"}, main.battle_player_tile, 50, {})
	print("A blocked direction (back, into a rock) is left out: %s (expected {left:(1,0), right:(-1,0)}, no 'back')" % [main.battle_evasion_options])
	main.evasion_direction_chosen.emit(main.battle_evasion_options["left"])
	main.battle_terrain.clear()

	# --- If a dodge happens with nowhere at all to roll, the prompt never
	# opens in the first place -- no pause, no empty choice. ---
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_terrain[Vector2i(4, 3)] = {"type": "rock"}
	main.battle_terrain[Vector2i(5, 4)] = {"type": "rock"}
	main.battle_terrain[Vector2i(3, 4)] = {"type": "rock"}
	main._enemy_apply_damage({"tile": Vector2i(4, 5), "name": "Goblin"}, main.battle_player_tile, 50, {})
	print("Nowhere to dodge-roll -- the prompt is skipped entirely: battle_awaiting_evasion=%s (expected false)" % [main.battle_awaiting_evasion])
	main.battle_terrain.clear()
	player.meta_dodge_chance = 0.0

	# --- Every shield but the free Wooden Buckler docks the player's own
	# damage while raised -- Heavy Shield's 10% cut, checked here directly. ---
	player.owned_shields = {}
	player.equipped_shield = {}
	player.try_buy_shield(heavy)
	player.current_weapon = weapons_script.CLUB
	var g_penalty := _make_goblin(main, Vector2i(3, 4), 999999)
	main.battle_units = [g_penalty]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var penalized_dmg: int = 999999 - g_penalty.hp
	var expected_penalized_dmg: int = int(round(10 * weapons_script.CLUB.damage_mult * 0.9))
	print("Heavy Shield docks 10%% of the player's own damage: dealt=%d (expected %d)" % [penalized_dmg, expected_penalized_dmg])
	print("...the free Wooden Buckler has no such penalty: %.2f (expected 0.0)" % [buckler.get("damage_penalty_pct", 0.0)])

	# --- Every shield but the free Wooden Buckler also passively soaks a
	# flat % off every hit that actually lands -- independent of (and
	# stacking with) the block_chance dice roll and Armor's own reduction.
	# Block forced to 0 here to isolate it from that roll. ---
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 0.0
	player.equipped_armor = {"damage_reduction": 0.0}
	main.battle_player_defending = false
	print("Heavy Shield passively soaks 10%% off a landed hit: dmg=%d (expected 90)" % [main._apply_incoming_reductions(100, {})])
	player.equipped_armor = {"damage_reduction": 0.2}
	print("...and stacks additively with Armor's own reduction (20%%+10%%=30%%): dmg=%d (expected 70)" % [main._apply_incoming_reductions(100, {})])
	player.equipped_armor = {"damage_reduction": 0.0}
	print("...the free Wooden Buckler has no such reduction either: %.2f (expected 0.0)" % [buckler.get("damage_reduction_pct", 0.0)])

	# --- Brawler's Buckler "vengeance": a successful block empowers only the
	# player's very next regular/heavy hit, then is consumed. ---
	var brawler: Dictionary = shields_script.SHIELDS.shield_brawler
	player.owned_shields = {}
	player.equipped_shield = {}
	player.try_buy_shield(brawler)
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 1.0
	player.shield_vengeance_active = false
	main._enemy_apply_damage({"tile": Vector2i(4, 5), "name": "Goblin"}, main.battle_player_tile, 50, {})
	print("Brawler's Buckler arms vengeance on a successful block: %s (expected true)" % [player.shield_vengeance_active])

	# Matches _apply_single_hit's actual sequential rounding: the shield's
	# own 10% damage penalty is applied (and rounded) first, THEN vengeance
	# multiplies on top of that already-reduced amount.
	var base_hit: int = int(round(10 * weapons_script.CLUB.damage_mult))
	var penalized_hit: int = int(round(base_hit * (1.0 - player.equipped_shield.get("damage_penalty_pct", 0.0))))

	var g_vengeance_1 := _make_goblin(main, Vector2i(3, 4), 999999)
	main.battle_units = [g_vengeance_1]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var vengeance_hit: int = 999999 - g_vengeance_1.hp
	var expected_vengeance_hit: int = int(round(penalized_hit * (1.0 + player.equipped_shield.special_pct)))
	print("...and empowers the very next hit: dealt=%d (expected %d, +%.0f%%, after its own 10%% penalty)" % [vengeance_hit, expected_vengeance_hit, player.equipped_shield.special_pct * 100])
	print("...then is consumed: %s (expected false)" % [player.shield_vengeance_active])

	var g_vengeance_2 := _make_goblin(main, Vector2i(3, 4), 999999)
	main.battle_units = [g_vengeance_2]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var followup_hit: int = 999999 - g_vengeance_2.hp
	print("...a THIRD hit (vengeance already spent) isn't boosted again: dealt=%d (expected %d, plain damage minus its own penalty)" % [
		followup_hit, penalized_hit
	])

	# --- shield_vengeance_active/battle_awaiting_evasion/battle_evasion_options
	# reset with the rest of the battle-scoped state in _setup_battle_grid. ---
	player.shield_vengeance_active = true
	main.battle_awaiting_evasion = true
	main.battle_evasion_options = {"back": Vector2i(0, -1)}
	main._setup_battle_grid([])
	print("Battle-scoped shield state resets at the start of a new battle: vengeance=%s awaiting_evasion=%s options=%s (expected false, false, {})" % [
		player.shield_vengeance_active, main.battle_awaiting_evasion, main.battle_evasion_options
	])

	# =========================================================
	# Shop integration
	# =========================================================
	# The battle-mechanics section above stripped equipped_armor down to just
	# {damage_reduction: 0.0} -- fine for _apply_incoming_reductions, but
	# _refresh_shop_display also reads its .name, so restore a real armor
	# dict before opening the shop again.
	player.equipped_armor = load("res://scripts/Armor.gd").TIERS[0]
	player.owned_shields = {}
	player.equipped_shield = {}
	player.coins = 1000
	main._open_shop()
	# The shop is a flat random lootpool now (see Main.gd:_roll_shop_offering)
	# -- a single visit isn't guaranteed to include a shield at all, let
	# alone all 5, so reroll until at least one turns up rather than assume
	# it's always there.
	var shield_idx := -1
	var attempts := 0
	while shield_idx < 0 and attempts < 50:
		for i in main.current_shop_offering.size():
			if main.current_shop_offering[i].category == "shield":
				shield_idx = i
				break
		if shield_idx < 0:
			main._roll_shop_offering()
			attempts += 1
	print("a shield eventually turns up in the lootpool: %s (expected true)" % [shield_idx >= 0])

	var bought_id: String = main.current_shop_offering[shield_idx].id
	main._on_shop_buy_pressed(shield_idx)
	print("Buying a shield through the shop equips it via try_buy_shield: owned=%s equipped=%s (expected true, %s)" % [
		player.owned_shields.has(bought_id), player.equipped_shield.get("id", ""), bought_id
	])
	main.shop_open = false
	main.get_tree().paused = false

	# Once owned, that specific shield is excluded from future rolls (it's a
	# one-time boolean-owned pickup, unlike a weapon variant or a potion) --
	# checked over many rerolls rather than a single one, since any given
	# roll might not include a shield at all to begin with.
	var saw_bought_shield_again := false
	for i in 100:
		main._roll_shop_offering()
		for it in main.current_shop_offering:
			if it.category == "shield" and it.id == bought_id:
				saw_bought_shield_again = true
	print("...specifically, the bought one never reappears: %s (expected false)" % [saw_bought_shield_again])
	main.shop_open = false
	main.get_tree().paused = false

	quit()
