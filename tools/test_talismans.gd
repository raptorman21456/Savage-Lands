extends SceneTree

# Talismans (Talismans.gd, Player.gd's talisman block) and the Seer
# (SeerPanel.gd): 28 passive charms, wearable in a number of slots that grows
# with level. Every effect is summed per key by Player.talisman_bonus and read
# at exactly one place in the game -- this checks the catalog, the slot and
# equip rules, the numbers, and that each kind of effect actually lands
# where it should.

const KNOWN_KEYS := [
	"damage_pct", "crit_chance", "crit_damage_mult_bonus", "low_hp_damage_pct", "low_hp_threshold",
	"burn_chance", "burn_chance_multihit", "first_attack_damage_pct",
	"traitor_wolf_chance_pct", "wolf_recruit_chance_min",
	"material_passive_boost", "survive_lethal",
	"fall_reduction", "ignore_ledge_attack", "water_push_prompt", "ally_defense_pct", "taunt_confusion",
	"hp_regen_turn", "heal_pct", "heal_on_kill", "stamina_regen",
	"special_stamina_flat_reduction",
	"luck", "coin_pct", "shop_discount", "coin_drop_chance", "attack_per_coin", "defense_per_coin", "xp_pct",
	"move_speed_pct", "reveal_all_locations", "gambling_luck", "phoenix", "fishing_luck",
	"arrow_unlimited", "arrow_price_pct",
	# --- Wildcard ---
	"max_hp_pct", "lifesteal_pct", "disable_healing_items", "momentum_chain",
	"whirlwind_double_melee", "weapon_whisperer", "special_stamina_pct_increase",
	"chaos_shard", "lock_hp_to_one", "oneshot_regular_enemies", "bloodmoon_fang",
	"ironclad_ward", "wildfire_core",
]
# Talismans.gd's doc comment also lists "special_stamina_discount",
# "break_reduction", "max_hp", "max_stamina", "dodge_chance", "block_heal",
# "damage_reduction", "coins_per_kill", "windfall_chance" and "move_range" as
# reserved -- no current talisman carries any of them (each used to live on a
# talisman this or the Offense/Defense/Sustain/Economy/Utility rework
# replaced), so they're left out of KNOWN_KEYS on purpose rather than failing
# the "every key is used" check below. Player.talisman_bonus still resolves
# them to 0.0 harmlessly.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}

# Fresh state between checks: everything unequipped, plenty of slots.
func _reset(player) -> void:
	player.equipped_talismans.clear()
	player.owned_talismans.clear()
	player._on_talismans_changed()
	player.level = 20

func _wear(player, ids: Array) -> void:
	for id in ids:
		player.owned_talismans[id] = true
		player.equipped_talismans.append(id)
	player._on_talismans_changed()

func _init() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var tal = load("res://scripts/Talismans.gd")
	var weapons = load("res://scripts/Weapons.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Catalog ---------------------------------------------------------------------
	var ids := {}
	var unique := true
	var all_valid := true
	for item in tal.ITEMS:
		if ids.has(item.id):
			unique = false
		ids[item.id] = true
		if item.price <= 0 or not tal.RARITY_WEIGHTS.has(item.rarity) or item.effects.is_empty() or item.description == "":
			all_valid = false
		for key in item.effects:
			if not KNOWN_KEYS.has(key):
				all_valid = false
				print("  unknown effect key %s on %s" % [key, item.id])
	print("at least 25 talismans exist: %d (expected >= 25)" % [tal.ITEMS.size()])
	print("ids are unique, prices positive, rarities and effect keys all valid: %s / %s (expected true / true)" % [unique, all_valid])
	var every_key_used := KNOWN_KEYS.all(func(k): return tal.ITEMS.any(func(i): return i.effects.has(k)))
	print("every effect key in the vocabulary is carried by some talisman: %s (expected true)" % [every_key_used])
	print("every talisman resolves an icon: %s (expected true)" % [tal.ITEMS.all(func(i): return not tal.get_talisman(i.id).get("icon", "").is_empty())])

	# --- Slots grow with level -----------------------------------------------------------
	print("slots by level (1, 3, 4, 7, 8, 11, 12, 99): %s (expected [1, 1, 2, 2, 3, 3, 4, 4])" % [
		[1, 3, 4, 7, 8, 11, 12, 99].map(func(l): return tal.slots_for_level(l))
	])
	print("the level each slot opens at: %s (expected [1, 4, 8, 12])" % [[1, 2, 3, 4].map(func(s): return tal.level_for_slot(s))])

	# --- Buying and wearing --------------------------------------------------------------
	player.level = 1
	player.owned_talismans.clear()
	player.equipped_talismans.clear()
	player._on_talismans_changed()
	player.coins = 200
	print("a level-1 player has 1 slot: %d (expected 1)" % [player.talisman_slots()])
	var ok: bool = player.try_buy_talisman("ember_charm")
	print("buying charges the price and wears it in the free slot: ok=%s (expected true), coins=%d (expected 130), worn=%s (expected [ember_charm])" % [ok, player.coins, player.equipped_talismans])
	print("...one of each only: %s (expected false), coins=%d (expected 130)" % [player.try_buy_talisman("ember_charm"), player.coins])
	player.try_buy_talisman("wolf_fang")
	print("a second charm with no free slot is owned but not worn: owned=%s (expected true), worn=%s (expected [ember_charm])" % [player.owned_talismans.has("wolf_fang"), player.equipped_talismans])
	print("...and can't be equipped until a slot opens: %s (expected false)" % [player.equip_talisman("wolf_fang")])
	player.level = 4
	print("reaching level 4 opens a second slot: %d (expected 2), equip works now: %s (expected true)" % [player.talisman_slots(), player.equip_talisman("wolf_fang")])
	print("unequipping frees the slot: %s (expected true), worn=%s (expected [ember_charm])" % [player.unequip_talisman("wolf_fang"), player.equipped_talismans])
	print("unowned/unknown/already-worn can't be equipped: %s %s %s (expected false false false)" % [player.equip_talisman("stone_amulet"), player.equip_talisman("nope"), player.equip_talisman("ember_charm")])
	player.coins = 1
	print("can't afford a charm: %s (expected false), coins=%d (expected 1)" % [player.try_buy_talisman("phoenix_ash"), player.coins])
	print("an unknown id is refused: %s (expected false)" % [player.try_buy_talisman("nope")])

	# --- Effects sum per key --------------------------------------------------------------
	_reset(player)
	_wear(player, ["ember_charm", "ember_charm"])
	print("effects sum across worn talismans: burn_chance=%.2f burn_chance_multihit=%.2f (expected 0.20 0.04)" % [
		player.talisman_bonus("burn_chance"), player.talisman_bonus("burn_chance_multihit")
	])
	_reset(player)
	print("nothing worn -> every bonus is 0: %s (expected true)" % [KNOWN_KEYS.all(func(k): return player.talisman_bonus(k) == 0.0)])

	# --- Idempotent equip/unequip; max HP / speed / stamina survive a level-up -------------
	var base_hp: int = player.max_health
	var base_speed: float = player.move_speed
	var base_stamina: int = player.max_stamina
	_wear(player, ["swift_feather"])
	# Nothing in the current catalog carries max_hp or max_stamina any more
	# (Turtle Shell and Deep Lung Charm moved off them in the Defense/Sustain
	# reworks) -- poked directly into the cache so the underlying mechanism
	# (Player._recalc_stats/_on_talismans_changed reading
	# talisman_bonus("max_hp")/("max_stamina")) still has real regression
	# coverage. Any equip/unequip below rebuilds the cache from
	# equipped_talismans and wipes this on its own, which is also exactly how
	# the "taking them off" check at the end expects it to disappear.
	player._talisman_cache["max_hp"] = 5
	player._recalc_stats()
	print("a max_hp bonus applies (no catalog talisman grants one right now): %d (expected %d)" % [player.max_health, base_hp + 5])
	print("Swift Feather +35%% move speed: %.1f (expected %.1f)" % [player.move_speed, base_speed * 1.35])
	# max_stamina isn't touched by _recalc_stats -- it's applied separately in
	# _on_talismans_changed (Player.gd:841), which also rebuilds the cache
	# from scratch first, wiping a poke like max_hp's above before it could be
	# read. Replicate just that one line instead of the whole function.
	player._talisman_cache["max_stamina"] = 15
	player.max_stamina = player._base_max_stamina + int(player.talisman_bonus("max_stamina"))
	print("a max_stamina bonus applies (no catalog talisman grants one right now): %d (expected %d)" % [player.max_stamina, base_stamina + 15])
	player._recalc_stats()
	print("a stat recalculation keeps them: hp=%d speed=%.1f stamina=%d (expected %d %.1f %d)" % [player.max_health, player.move_speed, player.max_stamina, base_hp + 5, base_speed * 1.35, base_stamina + 15])
	player.stat_vigor += 3
	player._recalc_stats()
	print("...and a level-up's vigor gain stacks on top: hp=%d (expected %d)" % [player.max_health, base_hp + 3 + 5])
	player.stat_vigor -= 3
	player._recalc_stats()
	player.unequip_talisman("swift_feather")
	print("taking them off restores the base exactly: hp=%d speed=%.1f stamina=%d (expected %d %.1f %d)" % [player.max_health, player.move_speed, player.max_stamina, base_hp, base_speed, base_stamina])
	print("...and health/stamina are clamped to the new max: %s (expected true)" % [player.health <= player.max_health and player.stamina <= player.max_stamina])

	# --- Economy -----------------------------------------------------------------------------
	_reset(player)
	player.meta_bonus_coin_pct = 0.0
	player.coins = 0
	_wear(player, ["merchants_coin"])
	player.add_coins(100)
	print("Merchant's Coin: +10%% coins: %d (expected 110)" % [player.coins])
	_reset(player)
	var potion: Dictionary = load("res://scripts/Potions.gd").get_tier("potion_health")
	var full_price: int = player.get_potion_price(potion)
	_wear(player, ["hagglers_tooth"])
	print("Haggler's Tooth: shop_discount is 10%%: %.2f (expected 0.10)" % [player.talisman_bonus("shop_discount")])
	print("...off shop prices: %d -> %d (expected 15 -> 14)" % [full_price, player.get_potion_price(potion)])
	_reset(player)
	player.luck_bonus = 0.0
	_wear(player, ["lucky_clover"])
	print("Lucky Clover: total luck %.2f (expected 0.50)" % [player.total_luck()])
	_reset(player)
	_wear(player, ["gilded_scarab"])
	player.coins = 100
	print("Gilded Scarab: scales with coins held: attack_bonus=%.2f (expected 12.50), defense_bonus=%.2f (expected 10.00)" % [
		player.coin_scaled_attack_bonus(), player.coin_scaled_defense_bonus()
	])
	player.equipped_armor = load("res://scripts/Armor.gd").TIERS[0]
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	print("...folded into armor_damage_reduction: %.2f (expected 10.00)" % [player.armor_damage_reduction()])
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "enemy"
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_last_stand_pct_per_10 = 0.0
	player.equipped_shield = {}
	player.potion_resilience_turns = 0
	main.battle_player_defending = false
	print("...through the real damage path, still capped at 90%% total: 100 -> %d (expected 10)" % [main._apply_incoming_reductions(100, {})])

	# The attack side lands through the real damage formula too -- and only
	# for the player's own hits, not an ally's.
	player.coins = 80
	player.berserk_turns_remaining = 0
	main.battle_turn = "player"
	player.current_weapon = weapons.CLUB
	player.stat_strength = 10
	player.attack_damage = 10
	player.temp_damage_bonus_pct = 0.0
	player.stamina = player.max_stamina
	main.battle_target_index = 0
	var scarab_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [scarab_target]
	main._battle_player_fight()
	print("Gilded Scarab: attack power scales into a real hit: dealt=%d (expected %d)" % [999 - scarab_target.hp, 20])
	var scarab_ally_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [scarab_ally_target]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "Your Wolf", Vector2i(2, 2))
	print("...but not an ally's hit: dealt=%d (expected 10)" % [999 - scarab_ally_target.hp])
	main.in_battle = false
	player.coins = 0
	_reset(player)

	# Tax Collector's Seal: a chance for any landed hit to drop an extra coin
	# -- not from a boss-tier enemy.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	player.coins = 0
	player.meta_bonus_coin_pct = 0.0
	_wear(player, ["tax_collectors_seal"])
	player._talisman_cache["coin_drop_chance"] = 1.0
	main.battle_units = [_make_goblin(main, Vector2i(3, 2))]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 1, false)
	print("Tax Collector's Seal: a landed hit can drop a coin: coins=%d (expected 1)" % [player.coins])
	player.coins = 0
	var boss_target := _make_goblin(main, Vector2i(3, 2))
	boss_target.name = "Boss"
	main.battle_units = [boss_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 1, false)
	print("...but not from a boss-tier enemy: coins=%d (expected 0)" % [player.coins])
	main.in_battle = false
	_reset(player)

	# --- XP -------------------------------------------------------------------------------------
	player.level = 5
	player.xp = 0
	player.xp_to_next = 100000
	_wear(player, ["scholars_quill"])
	player.gain_xp(100)
	print("Scholar's Quill: +15%% xp: %d (expected 115)" % [player.xp])
	_reset(player)

	# --- Healing -------------------------------------------------------------------------------------
	player.meta_healing_bonus_pct = 0.0
	_wear(player, ["healers_knot"])
	player.max_health = 200
	player.health = 1
	player.add_potion("potion_health")
	var result: Dictionary = player.use_healing_item()
	print("Healer's Knot: potions heal 25%% more: %d (expected 25)" % [result.get("healed", -1)])
	_reset(player)
	player._recalc_stats()

	# --- Defence -------------------------------------------------------------------------------------
	# Stone Amulet no longer grants flat damage reduction -- it amplifies
	# whichever weapon-material passive (Weapons.gd:MATERIALS) is active for
	# the player's current weapon instead. The materials' own passives get
	# dedicated coverage in test_weapon_materials.gd; this just proves the
	# amulet's boost is wired up, using Gold's Gilded Strike (a flat, fully
	# deterministic coin bonus) as the integration case.
	print("no talisman: material_passive_boost reads 0: %.2f (expected 0.00)" % [player.talisman_bonus("material_passive_boost")])
	_wear(player, ["stone_amulet"])
	print("Stone Amulet: material_passive_boost is active: %.2f (expected 1.00)" % [player.talisman_bonus("material_passive_boost")])
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	var gold_weapon: Dictionary = weapons.SPEAR.duplicate(true)
	gold_weapon.material_id = "gold"
	player.current_weapon = gold_weapon
	player.coins = 0
	player.meta_bonus_coin_pct = 0.0
	# "ref": null, not a real Enemy node -- a real node's .died signal would
	# refresh Rage/Berserk and grant XP (see _on_enemy_died), polluting the
	# exact-damage-value assertions later in this file (Duelist's Coin etc).
	main.battle_units = [{"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2, "damage": 0, "name": "Goblin"}]
	main._apply_single_hit(0, 1.0, "", gold_weapon, "You", Vector2i(-1, -1), 999, false)
	print("Gilded Strike's coin bonus is doubled by Stone Amulet: coins=%d (expected 2)" % [player.coins])
	_reset(player)
	player.coins = 0
	main.battle_units = [{"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2, "damage": 0, "name": "Goblin"}]
	main._apply_single_hit(0, 1.0, "", gold_weapon, "You", Vector2i(-1, -1), 999, false)
	print("...but without the amulet, just the base +1: coins=%d (expected 1)" % [player.coins])
	player.current_weapon = weapons.CLUB
	player.berserk_turns_remaining = 0
	main.in_battle = false
	_reset(player)

	# Cliffwalker's Bead: no fall damage at all, and any weapon can now
	# attack up a ledge/cliff drop.
	print("no talisman: the old default fall factor is 1.00 (no reduction): %.2f (expected 1.00)" % [player.fall_damage_factor()])
	_wear(player, ["cliffwalkers_bead"])
	print("Cliffwalker's Bead: immune to fall damage: %.2f (expected 0.00)" % [player.fall_damage_factor()])
	main.battle_terrain.clear()
	# diff (target - attacker) must equal -dir for the ledge gate to trigger --
	# (1, 0) == -(-1, 0), i.e. attacking up from directly below the drop.
	main.battle_terrain[Vector2i(3, 2)] = {"type": "ledge", "dir": Vector2i(-1, 0)}
	print("a melee attack up a ledge is normally blocked: %s (expected false)" % [main._can_battle_attack(Vector2i(2, 2), Vector2i(3, 2), 1, false, false)])
	print("...but not with the talisman's own bypass flag: %s (expected true)" % [main._can_battle_attack(Vector2i(2, 2), Vector2i(3, 2), 1, false, player.talisman_bonus("ignore_ledge_attack") > 0.0)])
	main.in_battle = true
	main.battle_player_tile = Vector2i(2, 2)
	var ledge_enemy := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [ledge_enemy]
	_reset(player)
	print("integrated through _targetable_indices: not targetable without the bead: %s (expected [])" % [main._targetable_indices()])
	_wear(player, ["cliffwalkers_bead"])
	print("...targetable with it equipped: %s (expected [0])" % [main._targetable_indices()])
	main.in_battle = false
	main.battle_terrain.clear()
	_reset(player)

	# Guardian Knot: allies take less damage -- their only reduction source.
	main.in_battle = true
	main.battle_player_tile = Vector2i(0, 0)
	var ally := {"tile": Vector2i(5, 5), "hp": 200, "max_hp": 200, "name": "Ally", "dmg_mult": 1.0, "move_range": 2, "attack_range": 1}
	main.battle_allies = [ally]
	main.battle_units = []
	main._enemy_apply_damage({"ref": null, "tile": Vector2i(5, 6)}, Vector2i(5, 5), 100, {})
	print("no talisman: an ally takes the raw hit: hp=%d (expected 100)" % [ally.hp])
	ally.hp = 200
	_wear(player, ["guardian_knot"])
	main._enemy_apply_damage({"ref": null, "tile": Vector2i(5, 6)}, Vector2i(5, 5), 100, {})
	print("Guardian Knot: allies take 20%% less: hp=%d (expected 120)" % [ally.hp])
	main.battle_allies = []
	_reset(player)

	# Wind Chime: taunt-confusion picks whichever combatant (player, ally, or
	# another enemy) is nearest to the confused enemy, instead of forcing
	# everyone onto the player -- friendly fire included.
	print("no talisman: taunt_confusion reads 0 (Taunt still just forces onto the player): %.2f (expected 0.00)" % [player.talisman_bonus("taunt_confusion")])
	_wear(player, ["wind_chime"])
	print("Wind Chime: taunt_confusion is active: %.2f (expected 1.00)" % [player.talisman_bonus("taunt_confusion")])
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_allies = [{"tile": Vector2i(10, 10), "hp": 20, "max_hp": 20, "name": "Ally", "dmg_mult": 1.0, "move_range": 2, "attack_range": 1}]
	var near_player := _make_goblin(main, Vector2i(2, 3))
	var near_ally := _make_goblin(main, Vector2i(10, 11))
	var pair_a := _make_goblin(main, Vector2i(20, 20))
	var pair_b := _make_goblin(main, Vector2i(20, 21))
	main.battle_units = [near_player, near_ally, pair_a, pair_b]
	print("an enemy next to the player targets the player: %s (expected (2, 2))" % [main._pick_confused_target_tile(near_player)])
	print("an enemy next to the ally targets the ally: %s (expected (10, 10))" % [main._pick_confused_target_tile(near_ally)])
	print("two enemies standing together, far from anyone else, target EACH OTHER: %s %s (expected (20, 21) (20, 20))" % [
		main._pick_confused_target_tile(pair_a), main._pick_confused_target_tile(pair_b)
	])
	# And the friendly-fire hit actually lands, through the real damage path.
	main.battle_units = [pair_b]
	main._enemy_apply_damage(pair_a, pair_b.tile, 50, {})
	print("...and it actually deals damage: pair_b hp=%d (expected 949)" % [pair_b.hp])
	main.in_battle = false
	main.battle_allies = []
	_reset(player)

	# Turtle Shell: the water push at the end of a turn asks first instead of
	# just happening -- only when the player is actually on a water tile.
	# _end_player_turn contains an await on this path (same shape as
	# _prompt_evasion_reposition), so it suspends right at the prompt when
	# called without its own await, exactly like the real game leaves it
	# suspended for a UI click.
	main.in_battle = true
	main.battle_allies = []
	main.battle_units = []
	main.battle_skill_cooldown = 0
	player.equipped_shield = {}
	main.battle_player_tile = Vector2i(3, 3)
	main.battle_terrain = {Vector2i(3, 3): {"type": "water", "push_dir": Vector2i(1, 0)}}
	_wear(player, ["turtle_shell"])
	main._end_player_turn()
	print("standing on water with Turtle Shell: a prompt opens instead of an immediate push: awaiting=%s (expected true), tile_unchanged_yet=%s (expected true)" % [
		main.battle_awaiting_water_confirm, main.battle_player_tile == Vector2i(3, 3)
	])
	main.water_push_prompt_choice.emit(false)
	for i in 3:
		await process_frame
	print("declining holds your ground: tile=%s (expected (3, 3)), awaiting=%s (expected false)" % [main.battle_player_tile, main.battle_awaiting_water_confirm])
	main.battle_player_tile = Vector2i(3, 3)
	main._end_player_turn()
	main.water_push_prompt_choice.emit(true)
	for i in 3:
		await process_frame
	print("accepting lets the current carry you: tile=%s (expected (4, 3), push_dir (1, 0))" % [main.battle_player_tile])
	main.in_battle = false
	main.battle_terrain.clear()
	_reset(player)

	# Without the talisman, the push just happens immediately -- no prompt.
	main.in_battle = true
	main.battle_player_tile = Vector2i(3, 3)
	main.battle_terrain = {Vector2i(3, 3): {"type": "water", "push_dir": Vector2i(1, 0)}}
	main._end_player_turn()
	for i in 3:
		await process_frame
	print("without the talisman, the push is immediate, no prompt: tile=%s (expected (4, 3)), awaiting=%s (expected false)" % [main.battle_player_tile, main.battle_awaiting_water_confirm])
	main.in_battle = false
	main.battle_terrain.clear()
	_reset(player)

	# --- Offence: real damage, real weapons ------------------------------------------------------------
	player.stat_strength = 10
	player.attack_damage = 10
	player.temp_damage_bonus_pct = 0.0
	player.stamina = player.max_stamina
	main.battle_target_index = 0
	main.battle_turn = "player"
	player.equipped_talismans.clear()
	main.in_battle = false

	# Duelist's Coin: -15% damage on every hit, but crits deal 250% (not the
	# usual 200%) and are 5% more likely.
	_reset(player)
	player.meta_crit_chance = 0.0
	print("no talisman: crit multiplier is the usual 2.0x: %.2f (expected 2.00)" % [player.crit_damage_mult()])
	_wear(player, ["duelists_coin"])
	print("Duelist's Coin: -15%% damage_pct, +5%% crit chance, crit multiplier 2.5x: %.2f %.2f %.2f (expected -0.15 0.05 2.50)" % [
		player.talisman_bonus("damage_pct"), player.crit_chance_total(), player.crit_damage_mult()
	])
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	# Duelist's Coin's own +5% crit_chance could occasionally fire a real crit
	# here too (randf() < 0.05) -- zeroed just for this one hit so the
	# non-crit case is actually deterministic; the forced-crit hit right after
	# doesn't need it restored, since meta_crit_chance=1.0 guarantees a crit
	# on top of any crit_chance value.
	player._talisman_cache["crit_chance"] = 0.0
	var pre_crit := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [pre_crit]
	main._battle_player_fight()
	print("...a real (non-crit) hit lands at round(10 x 0.85): dealt=%d (expected 9)" % [999 - pre_crit.hp])
	player.meta_crit_chance = 1.0
	var crit_hit := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [crit_hit]
	main._battle_player_fight()
	print("...a forced crit lands at round(9 x 2.5): dealt=%d (expected 23)" % [999 - crit_hit.hp])
	player.meta_crit_chance = 0.0
	main.in_battle = false
	_reset(player)

	# Whetstone Pendant: the first hit of the battle (player OR ally) hits 33%
	# harder; every hit after that is unaffected.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	main.battle_first_attack_used = false
	_wear(player, ["whetstone_pendant"])
	var first_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [first_target]
	main._battle_player_fight()
	print("Whetstone Pendant: the battle's first hit deals +33%%: dealt=%d (expected 13), flag_consumed=%s (expected true)" % [999 - first_target.hp, main.battle_first_attack_used])
	var second_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [second_target]
	main._battle_player_fight()
	print("...but the second hit of the same battle doesn't: dealt=%d (expected 10)" % [999 - second_target.hp])
	# It's genuinely "whichever comes first" -- an ally's hit consumes it too.
	main.battle_first_attack_used = false
	var ally_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [ally_target]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "Your Wolf", Vector2i(2, 2))
	print("...an ally's hit can consume it just as well: dealt=%d (expected 13, +33%%), flag_consumed=%s (expected true)" % [999 - ally_target.hp, main.battle_first_attack_used])
	main.in_battle = false
	_reset(player)

	# Berserker's Knot: a much bigger low-HP bonus at a tighter (riskier)
	# threshold than the skill tree's own 30%.
	print("no talisman: the default low-HP threshold is 30%%: %.2f (expected 0.30)" % [player.low_hp_threshold()])
	_wear(player, ["berserkers_knot"])
	print("Berserker's Knot: +100%% damage, threshold tightened to 20%%: %.2f %.2f (expected 1.00 0.20)" % [player.low_hp_damage_bonus_total(), player.low_hp_threshold()])
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	main.battle_first_attack_used = true
	player.max_health = 100
	player.health = 25
	var above_threshold := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [above_threshold]
	main._battle_player_fight()
	print("at 25%% HP (above the 20%% trigger): no bonus yet: dealt=%d (expected 10)" % [999 - above_threshold.hp])
	player.health = 15
	var below_threshold := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [below_threshold]
	main._battle_player_fight()
	print("at 15%% HP (at or below 20%%): full +100%%: dealt=%d (expected 20)" % [999 - below_threshold.hp])
	main.in_battle = false
	_reset(player)

	# Ember Charm: a chance per landed hit to set the target alight, much
	# smaller on multi-hit actions so a 5-10-hit flurry doesn't near-guarantee
	# a burn. _talisman_cache is poked directly to drive the roll to 100%/0%,
	# rather than relying on the real (much smaller) rolled odds -- the actual
	# catalog values are covered by the Seer's own rarity-weighted roll test
	# elsewhere in this file.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "enemy"
	player._talisman_cache["burn_chance"] = 1.0
	player._talisman_cache["burn_chance_multihit"] = 1.0
	var burn_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [burn_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), -1, false)
	print("Ember Charm: a single hit can set the target on fire: %s (expected true)" % [burn_target.get("burning", false)])
	var multihit_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [multihit_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), -1, true)
	print("...the multi-hit chance works too: %s (expected true)" % [multihit_target.get("burning", false)])
	player._talisman_cache["burn_chance"] = 0.0
	player._talisman_cache["burn_chance_multihit"] = 0.0
	var no_charm_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [no_charm_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), -1, false)
	print("with the charm off, hits don't ignite: %s (expected false)" % [no_charm_target.get("burning", false)])
	# An ally's hit never carries the player's own Ember Charm, even primed.
	player._talisman_cache["burn_chance"] = 1.0
	var ember_ally_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [ember_ally_target]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "Your Wolf", Vector2i(2, 2))
	print("an ally's hit doesn't ignite from the player's own Ember Charm: %s (expected false)" % [ember_ally_target.get("burning", false)])
	main.in_battle = false
	_reset(player)

	# Wolf Fang: a relative bump to the Traitor Wolf spawn-swap roll, and a
	# floor (not a further addition) on the recruit-on-death chance.
	print("base traitor-wolf odds: spawn=%.2f recruit=%.2f (expected 0.15 0.25)" % [main.TRAITOR_WOLF_CHANCE, main.TRAITOR_WOLF_RECRUIT_CHANCE])
	print("with no talisman, recruit chance is just the base 25%%: %s (expected true)" % [maxf(main.TRAITOR_WOLF_RECRUIT_CHANCE, player.talisman_bonus("wolf_recruit_chance_min")) == main.TRAITOR_WOLF_RECRUIT_CHANCE])
	_wear(player, ["wolf_fang"])
	var spawn_chance: float = main.TRAITOR_WOLF_CHANCE * (1.0 + player.talisman_bonus("traitor_wolf_chance_pct"))
	print("Wolf Fang: spawn-swap odds rise 25%% relative: %.4f (expected %.4f)" % [spawn_chance, main.TRAITOR_WOLF_CHANCE * 1.25])
	var recruit_chance: float = maxf(main.TRAITOR_WOLF_RECRUIT_CHANCE, player.talisman_bonus("wolf_recruit_chance_min"))
	print("...and the recruit chance is floored at 30%%, not 25+30: %.2f (expected 0.30)" % [recruit_chance])
	_reset(player)

	# Heal on kill.
	_wear(player, ["bloodstone"])
	# (After _wear: equipping recalculates max HP from vigor, which would clamp
	# a health value set beforehand.)
	player.max_health = 100
	player.health = 10
	main._on_enemy_died(0)
	print("Bloodstone: +3 HP on a kill: %d (expected 13)" % [player.health])
	_reset(player)

	# Deep Lung Charm: -5 stamina cost on every weapon special, stamped at
	# equip time -- the same mechanism the Reserved special_stamina_discount
	# key already used, just additive instead of percentage (see
	# Player.gd:_apply_talisman_to_weapon).
	player.coins = 1000
	player.try_buy_weapon(weapons.SPEAR)
	var base_special_cost: int = player.current_weapon.specials[0].stamina_cost
	_wear(player, ["deep_lung_charm"])
	print("Deep Lung Charm: -5 stamina cost on every special: %d (expected %d)" % [player.current_weapon.specials[0].stamina_cost, base_special_cost - 5])
	_reset(player)
	print("...and unequipping restores the normal cost: %d (expected %d)" % [player.current_weapon.specials[0].stamina_cost, base_special_cost])

	# --- Survival: Phoenix Ash, once per run ---------------------------------------------------------------
	player.max_health = 100
	player.health = 5
	player.phoenix_used = false
	player.meta_favour_chance = 0.0
	_wear(player, ["phoenix_ash"])
	player.take_battle_damage(999)
	print("Phoenix Ash: a killing blow leaves 1 HP: health=%d (expected 1), used=%s (expected true)" % [player.health, player.phoenix_used])
	var died := [false]
	player.died.connect(func(): died[0] = true)
	player.health = 5
	player.take_battle_damage(999)
	print("...but only once a run: died=%s (expected true)" % [died[0]])
	_reset(player)
	player.phoenix_used = false
	player.health = 5
	player.take_battle_damage(999)
	print("without the charm a killing blow kills: health=%d (expected 0)" % [player.health])
	# Iron Will Band shares the once-per-battle Favour chance.
	player.health = 50
	player.max_health = 100
	player.second_chance_used_this_battle = false
	_wear(player, ["iron_will_band"])
	print("Iron Will Band adds a survive-lethal chance: %.2f (expected 0.10)" % [player.talisman_bonus("survive_lethal")])
	_reset(player)

	# Pathfinder's Compass: a venue only shows on the Map tab once the player
	# has actually reached its door (Main.gd:_try_open_panel stamps
	# discovered_locations), unless the talisman reveals everything up front.
	# main.game_over is still true from the Phoenix Ash deaths above, so
	# _town_door_blocked() refuses to actually open whichever panel this
	# is -- discovery is stamped before that check either way, so this stays
	# a clean, side-effect-free way to exercise it.
	player.discovered_locations.clear()
	var any_kind: String = main.town_building_positions.keys()[0]
	print("nothing discovered yet: %s (expected false)" % [player.discovered_locations.get(any_kind, false)])
	main._try_open_panel(any_kind)
	print("reaching a venue's door discovers it: %s (expected true)" % [player.discovered_locations.get(any_kind, false)])
	player.discovered_locations.clear()
	print("no talisman: reveal_all_locations reads 0: %.2f (expected 0.00)" % [player.talisman_bonus("reveal_all_locations")])
	_wear(player, ["pathfinders_compass"])
	print("Pathfinder's Compass: reveal_all_locations is active: %.2f (expected 1.00)" % [player.talisman_bonus("reveal_all_locations")])
	_reset(player)

	# --- Wildcard talismans: extreme, build-defining trade-offs -------------------------------------------------
	player.stat_vigor = 100
	_reset(player)
	var base_max_hp: int = player.max_health
	_wear(player, ["glass_cannon_charm"])
	print("Glass Cannon Charm: -50%% max HP: %d (expected %d), +75%% damage_pct: %.2f (expected 0.75)" % [
		player.max_health, int(round(base_max_hp * 0.5)), player.talisman_bonus("damage_pct")
	])
	_reset(player)

	# Vampire's Pact: 25% lifesteal on landed hits; potions/food disabled.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	player.current_weapon = weapons.CLUB
	_wear(player, ["vampires_pact"])
	player.max_health = 100
	player.health = 50
	var pact_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [pact_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 20, false)
	print("Vampire's Pact: heals 25%% of damage dealt: health=%d (expected %d)" % [player.health, 55])
	player.add_potion("potion_health")
	var pact_result: Dictionary = player.use_healing_item()
	print("...and potions/food no longer work at all: %s (expected true, empty result)" % [pact_result.is_empty()])
	main.in_battle = false
	_reset(player)

	# Momentum Chain: +8%/stack uncapped while unhit; taking a hit resets the
	# chain and costs a turn.
	main.in_battle = true
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_momentum_chain_stacks = 0
	main.battle_player_turns_to_skip = 0
	main.battle_player_defending = false
	main.player_bleeding = false
	player.berserk_turns_remaining = 0
	player.equipped_shield = {}
	_wear(player, ["momentum_chain"])
	var chain_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [chain_target]
	var chain_before1: int = chain_target.hp
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 10, false)
	var chain_dealt1: int = chain_before1 - chain_target.hp
	var chain_before2: int = chain_target.hp
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 10, false)
	var chain_dealt2: int = chain_before2 - chain_target.hp
	print("Momentum Chain: each unhit hit lands harder than the last: %d then %d (expected 10 then %d)" % [chain_dealt1, chain_dealt2, int(round(10 * 1.08))])
	main._enemy_apply_damage({"ref": null, "tile": Vector2i(5, 6)}, Vector2i(2, 2), 5, {})
	print("...but taking a hit resets the chain and costs a turn: stacks=%d (expected 0), turns_to_skip=%d (expected 1)" % [main.battle_momentum_chain_stacks, main.battle_player_turns_to_skip])
	main.battle_player_turns_to_skip = 0
	main.in_battle = false
	_reset(player)

	# Whirlwind Charm: melee regular Attacks land twice, all damage cut to 40%.
	# current_weapon is set AFTER _wear -- _wear's _on_talismans_changed calls
	# _equip_weapon(current_weapon_base) internally, which would otherwise
	# silently re-equip whatever weapon was owned before this block (Deep
	# Lung Charm's Spear) and clobber a CLUB set beforehand.
	main.in_battle = true
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10
	player.temp_damage_bonus_pct = 0.0
	player.stamina = player.MAX_STAMINA
	_wear(player, ["whirlwind_charm"])
	player.current_weapon = weapons.CLUB
	var whirl_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [whirl_target]
	main._battle_player_fight()
	print("Whirlwind Charm: a melee Attack lands twice at 40%% damage each: dealt=%d (expected %d)" % [999 - whirl_target.hp, 2 * int(round(10 * 0.4))])
	var spear_weapon: Dictionary = weapons.SPEAR.duplicate(true)
	player.current_weapon = spear_weapon
	var whirl_spear_target := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [whirl_spear_target]
	main._battle_player_fight()
	print("...but a long-range weapon (Spear) doesn't double-hit: dealt=%d (expected %d)" % [999 - whirl_spear_target.hp, int(round(int(round(10 * 0.55)) * 0.4))])
	main.in_battle = false
	_reset(player)

	# Weapon Whisperer: pick any 3 learned specials (any weapon type) as your
	# loadout; specials cost 50% more stamina.
	player.learned_specials.clear()
	player.owned_weapons["club"] = true
	player.owned_weapons["spear_fine_steel"] = true
	player.try_learn_special("spear_piercing_thrust")
	player.coins += 1000
	_wear(player, ["weapon_whisperer"])
	player.weapon_whisperer_specials = []
	player.toggle_whisperer_special("spear_piercing_thrust")
	player.try_buy_weapon(weapons.CLUB)
	print("Weapon Whisperer: a learned Spear move replaces the Club's own special: %s (expected spear_piercing_thrust)" % [player.current_weapon.specials[0].id])
	print("...at +50%% stamina cost: %d (expected %d)" % [player.current_weapon.specials[0].stamina_cost, int(round(33 * 1.5))])
	player.weapon_whisperer_specials = []
	_reset(player)

	# Chaos Shard: every hit's damage rerolled to 50%-160% of normal.
	main.in_battle = true
	player.current_weapon = weapons.CLUB
	_wear(player, ["chaos_shard"])
	var chaos_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [chaos_target]
	var chaos_min := 99999
	var chaos_max := 0
	for i in 200:
		var chaos_before: int = chaos_target.hp
		main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 100, false)
		var chaos_dealt: int = chaos_before - chaos_target.hp
		chaos_min = mini(chaos_min, chaos_dealt)
		chaos_max = maxi(chaos_max, chaos_dealt)
	print("Chaos Shard: damage varies between 50%% and 160%% of normal over 200 trials: min=%d max=%d (expected roughly 50-60 and 150-160)" % [chaos_min, chaos_max])
	main.in_battle = false
	_reset(player)

	# Last Stand Idol: oneshots regular enemies (bosses excluded); HP locked
	# to 1 no matter what.
	player.stat_vigor = 500
	_reset(player)
	_wear(player, ["last_stand_idol"])
	print("Last Stand Idol: HP is locked to 1 regardless of Vigor: max_health=%d health=%d (expected 1 1)" % [player.max_health, player.health])
	main.in_battle = true
	player.current_weapon = weapons.CLUB
	var idol_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [idol_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 1, false)
	print("...and any hit instantly kills a regular enemy: hp=%d (expected <= 0)" % [idol_target.hp])
	player.berserk_turns_remaining = 0
	var idol_boss := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Boss"}
	main.battle_units = [idol_boss]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 1, false)
	print("...but a boss-tier enemy just takes the normal hit: dealt=%d (expected 1)" % [999999 - idol_boss.hp])
	main.in_battle = false
	_reset(player)
	player.stat_vigor = 100
	player._recalc_stats()

	# Bloodmoon Fang: kills stack +7.5% damage/+7.5% move speed each; 3 quiet
	# turns crash it to -50% all combat stats.
	main.in_battle = true
	main.battle_player_tile = Vector2i(2, 2)
	player.current_weapon = weapons.CLUB
	player.stat_strength = 10
	player.attack_damage = 10
	player.stat_agility = 100
	player.bloodmoon_stacks = 0
	player.bloodmoon_debuffed = false
	main.battle_bloodmoon_quiet_turns = 0
	main.battle_had_combat_action_this_cycle = false
	_wear(player, ["bloodmoon_fang"])
	var bm_kill_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [bm_kill_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 999, false)
	player.berserk_turns_remaining = 0
	print("Bloodmoon Fang: a kill stacks Bloodlust: stacks=%d (expected 1), move_speed reflects it: %.1f (expected %.1f)" % [
		player.bloodmoon_stacks, player.move_speed, 100.0 * (1.0 + 0.075)
	])
	var bm_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [bm_target]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 10, false)
	print("...and the damage bonus lands in a real hit: dealt=%d (expected %d)" % [999999 - bm_target.hp, int(round(10 * 1.075))])
	main.battle_had_combat_action_this_cycle = false
	main._advance_bloodmoon_quiet_turn()
	main.battle_had_combat_action_this_cycle = false
	main._advance_bloodmoon_quiet_turn()
	main.battle_had_combat_action_this_cycle = false
	main._advance_bloodmoon_quiet_turn()
	print("...3 quiet turns crash it: debuffed=%s (expected true), stacks=%d (expected 0)" % [player.bloodmoon_debuffed, player.bloodmoon_stacks])
	main.in_battle = false
	_reset(player)
	player.bloodmoon_stacks = 0
	player.bloodmoon_debuffed = false
	player.stat_agility = 5
	player._recalc_stats()

	# Ironclad Ward: Move is disabled entirely; defense x2.5.
	main.in_battle = true
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main.battle_player_moves_left = 5
	_wear(player, ["ironclad_ward"])
	main._on_battle_main_action("move")
	print("Ironclad Ward: Move is refused entirely: menu_state=%s (expected main, not move)" % [main.battle_menu_state])
	player.equipped_armor = load("res://scripts/Armor.gd").TIERS[1]
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	var base_dr: float = player.armor_tier_damage_reduction()
	print("...and defense is multiplied by 2.5x: %.3f (expected %.3f)" % [player.armor_damage_reduction(), base_dr * 2.5])
	main.in_battle = false
	_reset(player)

	# Wildfire Core: a burning kill explodes, damaging and igniting everything
	# nearby -- allies and the player included.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.player_burning = false
	_wear(player, ["wildfire_core"])
	player.max_health = 500
	player.health = 500
	var wf_ally := {"tile": Vector2i(3, 3), "hp": 500, "max_hp": 500, "name": "Ally", "dmg_mult": 1.0, "move_range": 2, "attack_range": 1}
	main.battle_allies = [wf_ally]
	var wf_bystander := _make_goblin(main, Vector2i(3, 3), 999)
	var wf_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 400, "move_range": 2, "damage": 0, "name": "Goblin", "burning": true}
	main.battle_units = [wf_target, wf_bystander]
	main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 999, false)
	var expected_blast: int = int(round(400 * 0.25))
	print("Wildfire Core: a burning kill explodes onto everything nearby: player_health=%d (expected %d), ally_hp=%d (expected %d), bystander_hp=%d (expected %d), bystander_burning=%s (expected true), player_burning=%s (expected true)" % [
		player.health, 500 - expected_blast, wf_ally.hp, 500 - expected_blast, wf_bystander.hp, 999 - expected_blast, wf_bystander.burning, main.player_burning
	])
	main.in_battle = false
	main.battle_allies = []
	main.player_burning = false
	_reset(player)

	# --- The Seer ----------------------------------------------------------------------------------------------
	# (The deaths above tripped Main's game-over state, which blocks every door.)
	main.game_over = false
	paused = false
	player.max_health = 20
	player.health = 20
	player.level = 1
	player.owned_talismans.clear()
	player.equipped_talismans.clear()
	player._on_talismans_changed()
	var seen := {}
	for id in main.seer_stock:
		seen[id] = true
	print("the Seer starts with a full stock of distinct talismans: %d (expected 5), distinct=%s (expected true)" % [main.seer_stock.size(), seen.size() == main.seer_stock.size()])
	var stock_ok := true
	for id in main.seer_stock:
		if tal.get_talisman(id).is_empty():
			stock_ok = false
	print("...all real: %s (expected true)" % [stock_ok])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var owned_all := {}
	for item in tal.ITEMS:
		owned_all[item.id] = true
	print("nothing to offer when you own everything: %d (expected 0)" % [tal.roll_stock(5, owned_all, rng).size()])
	var owned_most := owned_all.duplicate()
	owned_most.erase("ember_charm")
	owned_most.erase("wolf_fang")
	print("a nearly-owned catalog offers only what's left: %s (expected the two, any order)" % [tal.roll_stock(5, owned_most, rng)])
	# Rarity weighting: commons dominate a big sample.
	var counts := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0}
	for i in 400:
		for id in tal.roll_stock(3, {}, rng):
			counts[tal.get_talisman(id).rarity] += 1
	print("stock is weighted toward common over epic (400 rolls x 3): %s (expected common > uncommon > epic)" % [counts])

	var seer = main.town_panels.get("seer")
	print("the Seer panel is registered: %s (expected true)" % [seer != null])
	if seer != null:
		player.coins = 500
		main.seer_stock = ["ember_charm", "stone_amulet", "wolf_fang", "gilded_scarab", "phoenix_ash"]
		main._try_open_panel("seer")
		print("the door opens it: visible=%s (expected true), title=%s (expected THE SEER)" % [seer.visible, seer.title_label.text])
		var coins_before: int = player.coins
		print("buying from the stock: ok=%s (expected true), coins spent=%d (expected 70), sold out of the stock=%s (expected true), worn=%s (expected [ember_charm])" % [
			seer.buy("ember_charm"), coins_before - player.coins, not main.seer_stock.has("ember_charm"), player.equipped_talismans
		])
		print("something not on offer can't be bought: %s (expected false)" % [seer.buy("iron_will_band")])
		player.coins = 5
		print("can't afford it: %s (expected false), still in stock=%s (expected true)" % [seer.buy("phoenix_ash"), main.seer_stock.has("phoenix_ash")])
		player.coins = 100
		var old_stock: Array = main.seer_stock.duplicate()
		print("a reroll costs 15 and re-stocks: ok=%s (expected true), coins=%d (expected 85), full stock=%s (expected 5)" % [seer.reroll(), player.coins, main.seer_stock.size()])
		print("...never re-offering what you own: %s (expected false)" % [main.seer_stock.has("ember_charm")])
		player.coins = 3
		print("can't afford a reroll: %s (expected false)" % [seer.reroll()])
		seer.close()

		# The stock turns over at every kill milestone.
		var stock_before: Array = main.seer_stock.duplicate()
		var differs := false
		for i in 10:
			main._roll_seer_stock()
			if main.seer_stock != stock_before:
				differs = true
		print("re-rolling produces a different stock: %s (expected true)" % [differs])
		main.seer_stock = []
		main._advance_wave_tier()
		print("advancing the wave tier restocks the Seer: %d (expected 5)" % [main.seer_stock.size()])

	# --- Inventory tab -------------------------------------------------------------------------------------------------
	player.level = 4
	player.owned_talismans.clear()
	player.equipped_talismans.clear()
	player._on_talismans_changed()
	player.owned_talismans["ember_charm"] = true
	player.owned_talismans["wolf_fang"] = true
	player.owned_talismans["stone_amulet"] = true
	var panel = main.inventory_panel
	panel.open(player)
	panel._select_tab("Talismans")
	print("the Inventory has a Talismans tab: %s (expected true), active=%s (expected Talismans)" % [panel.tab_containers.has("Talismans"), panel.active_tab])
	panel._on_talisman_cell_pressed("ember_charm")
	panel._on_talisman_cell_pressed("wolf_fang")
	panel._on_talisman_cell_pressed("stone_amulet")
	print("clicking wears up to the slot limit (2 at level 4): %s (expected [ember_charm, wolf_fang])" % [player.equipped_talismans])
	panel._on_talisman_cell_pressed("ember_charm")
	print("clicking a worn one takes it off: %s (expected [wolf_fang])" % [player.equipped_talismans])
	panel.close()

	quit()
