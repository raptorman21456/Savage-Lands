extends CharacterBody2D
class_name Player

const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")

signal health_changed(current: int, max_health: int)
signal xp_changed(current: int, needed: int)
signal stats_changed(intimidation: int, strength: int, vigor: int, agility: int, might: int)
signal leveled_up(new_level: int)
signal coins_changed(amount: int)
signal runic_shards_changed(amount: int)
signal items_changed(amount: int)
signal stamina_changed(current: int, max_stamina: int)
signal died

const INVINCIBILITY_TIME := 0.9
const FLASH_DURATION := 0.15
const BODY_RADIUS := 16.0
const ITEM_HEAL_AMOUNT := 5
# Overworld attack animation -- a lunge-and-scale-punch on the sprite itself,
# timed as a fraction of the current weapon's own active_duration (see
# _play_attack_animation). Safe to tween sprite.position/.scale directly:
# nothing else in this file ever touches those two properties per-frame
# (only .modulate for flash/i-frames and .flip_h for facing).
const ATTACK_LUNGE_DISTANCE := 12.0
const ATTACK_SCALE_PUNCH := 1.12
const BASE_SPRITE_SCALE := Vector2(2, 2)

# Stamina only exists for the tile battle -- it does not appear or do
# anything in the overworld. This is the base value before the permanent
# Endurance meta-upgrade; the actual ceiling for a given run is max_stamina.
const MAX_STAMINA := 100

# Exhausted: self-inflicted the instant stamina hits 0 (spend_stamina below)
# -- halves every regen_stamina gain until stamina recovers to
# EXHAUSTED_CLEAR_STAMINA_PCT of max, then auto-clears. No enemy source, no
# turn counter, fully self-contained here.
const EXHAUSTED_STAMINA_REGEN_MULT := 0.5
const EXHAUSTED_CLEAR_STAMINA_PCT := 0.5

const MAX_LEVEL := 99
const XP_BASE := 20
const XP_PER_LEVEL := 8

# Every stat maps 1:1 to its effect. Agility starts a little below the
# original 200 px/s baseline instead of at a tiny abstract number.
const AGILITY_START := 180
# Agility barely mattered when it only rose by +1 per level like everything
# else -- picking it as a level-up bonus grants a bigger jump instead, so
# committing to it actually shows up in overworld speed and battle move range.
const AGILITY_BONUS_PER_LEVEL := 5
const BASE_ATTACK_COOLDOWN := 0.35
const COOLDOWN_REDUCTION_PER_AGILITY := 0.003
const MIN_ATTACK_COOLDOWN := 0.12

var level := 1
var xp := 0
var xp_to_next := XP_BASE + XP_PER_LEVEL * level

var stat_intimidation := 0
var stat_strength := 1
var stat_vigor := 10
var stat_agility := AGILITY_START
# Might: a pure level-up stat like the 4 above, always available (no skill-
# tree unlock needed) -- gates equipping the top weapon tiers (see
# Weapons.gd:required_might) and boosts recruited-ally damage.
var stat_might := 0
# Resilience/Reflexes/Dexterity: also level-up stats, but each stays at 0
# and is skipped by _level_up's auto-+1 until its skill-tree unlock node is
# owned (meta_resilience_unlocked etc., set in _apply_meta_upgrades).
var stat_resilience := 0
var stat_reflexes := 0
var stat_dexterity := 0
var awaiting_bonus := false

var max_health := stat_vigor
var attack_damage := stat_strength
var move_speed: float = stat_agility
var attack_cooldown_max := BASE_ATTACK_COOLDOWN

var coins := 0
# Dropped only by elite enemies, spent in the shop's Enchant tab. Per-run
# just like coins/owned_weapons -- resets to 0 every new game.
var runic_shards := 0
var healing_items := 0
var potion_queue: Array = []
var current_weapon: Dictionary = WeaponsScript.CLUB
# The raw, pre-enchantment dict last passed to _equip_weapon -- kept
# separately so applying a new enchantment can always re-merge from a clean
# source instead of stacking a second merge on top of an already-enchanted
# current_weapon.
var current_weapon_base: Dictionary = WeaponsScript.CLUB
var owned_weapons := {"club": true}
var equipped_armor: Dictionary = ArmorScript.TIERS[0]
var owned_armor := {"armor_rags": true}
# Off-hand slot, independent of armor -- empty Dictionary means no shield
# carried. A shield's block chance/special ability only apply while
# current_weapon is one of Shields.COMPATIBLE_WEAPONS (see
# shield_block_chance()/shield_push_immune()/shield_evasion_active() below),
# but it stays owned/equipped regardless of what you switch to.
var equipped_shield: Dictionary = {}
var owned_shields := {}
# weapon id -> rune id. Applied by re-merging into current_weapon whenever
# that weapon is equipped (see _equip_weapon).
var weapon_enchantments := {}

var overworld_attack_locked := true
var max_stamina := MAX_STAMINA
var stamina := MAX_STAMINA
var exhausted := false

# Permanent meta-upgrade effects that don't map onto an existing in-run
# stat: Fortune biases shop weapon-tier rolls.
var luck_bonus := 0.0
# Resilience (core stat, unlocked via the "resilience_unlock" skill node --
# see _level_up/apply_bonus_stat): 1% damage reduction per point, capped at
# 20%, stacking with armor. Derived fresh in _recalc_stats from
# stat_resilience, not set directly from a skill-tree bonus.
const RESILIENCE_PCT_PER_POINT := 0.01
const RESILIENCE_REDUCTION_CAP := 0.20
var resilience_reduction := 0.0
# The active save slot's locked-in difficulty (SaveData.gd:DIFFICULTIES) --
# read by Main.gd:_setup_battle_grid to scale enemy HP/damage. Set in
# _apply_meta_upgrades from the save's "difficulty" field, same as every
# other save-derived value here.
var difficulty_mult := 1.0
# Ancient Shrine random event: a temporary blessing/curse on damage dealt,
# expiring after a fixed number of waves (see Main.gd:shrine_effect_waves_
# remaining). Read generically in _apply_single_hit, so it affects the
# player's own hits and the Blade Ally's alike.
var temp_damage_bonus_pct := 0.0

# Skill tree tier-4 passives -- stamped onto whatever weapon gets equipped
# (see _apply_meta_passives_to_weapon), not tied to any one weapon the way a
# Mythic legendary's passive is.
var meta_double_hit_chance := 0.0
var meta_lifesteal_pct := 0.0
var meta_free_specials := false
# Skill tree capstones with a whole new mechanic instead of a flat stat --
# read by Main.gd/HUD.gd rather than folded into a stat here.
var has_guardian_skill := false
var has_merchant_prince := false

# Deeper skill tree nodes (see SaveData.gd's Reflexes/Adrenaline/Haggling/
# Herbalism/Prodigy/Beastmaster) -- read at their one call site each, same
# pattern as the meta-passives above.
# Reflexes (core stat, unlocked via "reflexes_unlock"): 0.75% dodge chance
# per point, capped at 15%. Derived fresh in _recalc_stats from
# stat_reflexes, same pattern as resilience_reduction above.
const REFLEXES_PCT_PER_POINT := 0.0075
const REFLEXES_DODGE_CAP := 0.15
var meta_dodge_chance := 0.0
# Dexterity (core stat, unlocked via "dexterity_unlock"): 0.75% crit chance
# per point (double damage, ignores the rock-cover reduction), capped at
# 15%. Same derivation pattern.
const DEXTERITY_PCT_PER_POINT := 0.0075
const DEXTERITY_CRIT_CAP := 0.15
var meta_crit_chance := 0.0
# Whether the "resilience_unlock"/"reflexes_unlock"/"dexterity_unlock" skill
# nodes are owned -- gates whether the matching stat auto-grows on level-up
# and can be chosen as the bonus (see _level_up/apply_bonus_stat), same
# "unlock gate" shape as requires_lifetime_flag uses elsewhere in the tree.
var meta_resilience_unlocked := false
var meta_reflexes_unlocked := false
var meta_dexterity_unlocked := false
# Rage: bonus damage multiplier added on top of Berserk's own base bonus
# while Berserk is active (see berserk_turns_remaining below).
var meta_rage_bonus_pct := 0.0
# Adrenaline: extra damage DEALT (not reduced) while below 30% HP -- read in
# Main.gd:_apply_single_hit.
var meta_low_hp_damage_bonus_pct := 0.0
var meta_bonus_coin_pct := 0.0
var meta_healing_bonus_pct := 0.0
var meta_bonus_levelup_stat := false
# Cross-wing convergence nodes (Warband/Battle Medic/War Chest/War
# Profiteer) -- each requires investment from two different wings, read the
# same way.
var meta_warband_bonus := 0.0
var meta_battle_medic := false
var meta_war_chest_reduction := 0.0
var meta_war_profiteer_coins := 0

# Brawn/Swiftness/Vitality/Presence: instead of a flat starting-stat add,
# these boost the amount gained when you level up and choose that stat --
# see apply_bonus_stat(). Owning Brawn at level 2 turns a level-up's "+1
# Strength" choice into "+3 Strength" (1 base + 2 from the skill).
var meta_levelup_bonus_strength := 0
var meta_levelup_bonus_agility := 0
var meta_levelup_bonus_vigor := 0
var meta_levelup_bonus_intimidation := 0

# Block Master: chance to fully negate incoming damage while Defending.
var meta_block_negate_chance := 0.0
# Vigilant Defense (renamed from Resilience): flat HP healed every time you
# Defend.
var meta_block_heal_amount := 0
# Last Stand: damage reduction that scales with how much HP you're missing.
var meta_last_stand_pct_per_10 := 0.0
# Shield Mastery: flat bonus block chance added on top of any equipped
# shield's own block_chance, see shield_block_chance() below.
var meta_shield_block_bonus_pct := 0.0
# Unbreakable Guard: waives the shield/weapon compatibility check entirely
# (see _shield_weapon_ok() below), so a shield keeps working even with a
# two-handed weapon equipped.
var meta_shield_universal := false
# Riposte: chance, when Precision fully dodges a hit, to immediately
# counter-attack whoever swung at you.
var meta_riposte_chance := 0.0
# Momentum: damage bonus that stacks per kill THIS battle, read in
# Main.gd:_apply_single_hit against battle_momentum_stacks.
var meta_momentum_pct_per_kill := 0.0
# Hardened: permanent max-HP growth per wave cleared THIS run.
var meta_hardened_hp_per_wave := 0
# Favour (renamed from Second Chance): a %-chance, on any hit that would
# drop you to 0 HP, to survive at 1 HP instead -- still only ever once per
# battle. See take_battle_damage() below; second_chance_used_this_battle is
# reset by Main.gd:_setup_battle_grid at the start of every fight.
var meta_favour_chance := 0.0
var second_chance_used_this_battle := false
# Second Breath: passive Stamina regen at the start of every player turn,
# read in Main.gd's turn-cycle tail.
var meta_stamina_regen_per_turn := 0
# Pack Bond: extra waves added to WOLF_BASE_STAY_WAVES before a Traitor
# Wolf's loyalty expires, read in Main.gd.
var meta_wolf_bonus_waves := 0
# Investor (repurposed): extra weapon slots rolled into every shop offering.
var meta_investor_bonus_slots := 0
# Fletcher: special-arrow price discount and held-count cap bonus.
var meta_arrow_discount_pct := 0.0
var meta_arrow_cap_bonus := 0
# Field Surgeon: shop healing-potion price discount.
var meta_field_surgeon_discount_pct := 0.0
# Windfall: chance for a defeated enemy to drop bonus gold.
var meta_windfall_chance := 0.0
# Black Market: shop reroll price discount.
var meta_reroll_discount_pct := 0.0
# Worldwalker: the one-time reward for completing the Nothingness boss
# rush (see SaveData.gd's game_completed_ever lifetime flag) -- always-on
# +WORLDWALKER_HP_BONUS_PCT max HP and +WORLDWALKER_DAMAGE_BONUS_PCT damage,
# applied wherever max_health/attack_damage are (re)computed from raw stats
# (_apply_meta_upgrades, _recalc_stats).
const WORLDWALKER_HP_BONUS_PCT := 0.15
const WORLDWALKER_DAMAGE_BONUS_PCT := 0.10
var meta_worldwalker := false

# Party: combat companions that fight as real battle units on their own
# tile, with their own turn (Main.gd:battle_allies/_process_ally_turn).
# Each entry here is just the permanent roster: {"name": String, "dmg_mult":
# float}
# -- Blade Ally (skill tree) and a recruited Warrior (random event) are
# mechanically identical, so they share this one shape rather than needing
# separate flags. max_party_slots is upgraded by the Pack Leader skill tree
# node. party_wolf is a Traitor Wolf recruited via combat (Main.gd:
# _on_wolf_died) -- a single extra slot that doesn't count against
# max_party_slots (empty dict = no wolf).
var party_members: Array = []
var max_party_slots := 2
var party_wolf: Dictionary = {}

# Battle-scoped weapon-special state, reset at the start of every battle
# (Main.gd:_setup_battle_grid) -- none of it persists between fights.
# Disarmed (Spear's Target Practice on a miss, Dagger's Knife Throw): while
# not the sentinel, the battle Fight button is disabled until
# battle_player_tile == disarmed_tile.
var disarmed_tile := Vector2i(-1, -1)
# Brawler's Buckler (shield special "vengeance"): set true when a passive
# shield block triggers, consumed by the player's very next hit in
# Main.gd:_apply_single_hit for a damage bonus. Reset with the rest of this
# block's battle-scoped state in _setup_battle_grid.
var shield_vengeance_active := false
# Special-arrow inventory (replaces the Bow's specials) -- persists across
# battles/runs like coins/owned_weapons, not battle-scoped. Count-valued,
# unlike the id:true shape of owned_weapons/owned_armor.
var owned_arrows := {"flame": 0, "freeze": 0, "bomb": 0}
# Hand Picks' Pichaku: 80% damage + 20% double-hit chance on every regular/
# heavy attack for the rest of the current battle.
var pichaku_active := false
# Rage/Berserk: set/refreshed to BERSERK_TURNS (Main.gd) by _on_enemy_died
# whenever a kill lands mid-battle, decremented once per player turn
# alongside the other player-side turn counters. While > 0: damage dealt
# gets +50%+meta_rage_bonus_pct (Main.gd:_apply_single_hit), shields are
# unusable (shield_block_chance below), and Block Master/Reflexes dodge are
# both cut to a quarter of their normal rate (Main.gd:_apply_incoming_
# reductions/_enemy_apply_damage).
var berserk_turns_remaining := 0
# Stealth: set to STEALTH_TURNS (Main.gd) by _battle_player_stealth,
# decremented once per player turn alongside the other player-side turn
# counters. While > 0, an enemy only targets the player if it currently sees
# them (Main.gd:_enemy_currently_sees_player) -- otherwise it engages an
# ally or wanders. The player's own next attack breaks stealth immediately
# for a guaranteed crit (Main.gd:_apply_single_hit's stealth_forced_crit).
var stealth_turns_remaining := 0

var health := max_health
var facing := Vector2.DOWN
var attack_timer := 0.0
var attack_duration_total := 0.15
var sweep_start_angle := 0.0
var sweep_end_angle := 0.0
var cooldown_timer := 0.0
var invincible_timer := 0.0
var flash_timer := 0.0

var attack_area: Area2D
var attack_collision: CollisionShape2D
var sprite: Sprite2D
var attack_tween: Tween
var hit_this_swing := {}
var settings: Node

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Main is PROCESS_MODE_ALWAYS (needs to read menu/restart input while
	# paused). INHERIT would cascade that ALWAYS mode down to us, so we'd
	# never actually stop when the game pauses -- override it explicitly.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# The Settings autoload isn't resolvable as a bare global identifier at
	# GDScript compile time for a script loaded this early in a bare
	# SceneTree's first frame (confirmed empirically) -- a runtime node
	# lookup, cached once _ready() actually runs, sidesteps that entirely.
	settings = get_node("/root/Settings")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BODY_RADIUS
	collision.shape = shape
	add_child(collision)

	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/barbarian.png")
	sprite.scale = BASE_SPRITE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	# monitoring stays on permanently; toggling it per-swing doesn't reset
	# Godot's internal overlap bookkeeping, so an enemy that stays adjacent
	# across multiple swings would only ever fire body_entered once. Instead
	# we poll get_overlapping_bodies() each frame the swing is active.
	attack_area = Area2D.new()
	attack_area.monitoring = true
	attack_collision = CollisionShape2D.new()
	attack_area.add_child(attack_collision)
	add_child(attack_area)

	_apply_meta_upgrades()
	_equip_weapon(current_weapon)

# Applies every permanent, Essence-bought upgrade from past runs -- this is
# what makes a roguelike run start stronger than the last one, instead of
# every death resetting progress to zero. Recomputes derived stats directly
# rather than going through _recalc_stats(), since that emits signals Main.gd
# forwards straight to `hud` -- and this runs during _ready(), before Main
# has built the HUD those signals would be delivered to.
func _apply_meta_upgrades() -> void:
	var bonuses: Dictionary = SaveDataScript.get_applied_bonuses()
	difficulty_mult = SaveDataScript.get_difficulty_mult(SaveDataScript.load_data().get("difficulty", ""))
	# Might/Swiftness/Vitality/Presence no longer touch starting stats at
	# all -- they're stored here and applied per level-up instead, in
	# apply_bonus_stat().
	meta_levelup_bonus_strength = int(bonuses.get("strength", 0))
	meta_levelup_bonus_agility = int(bonuses.get("agility", 0))
	meta_levelup_bonus_vigor = int(bonuses.get("vigor", 0))
	meta_levelup_bonus_intimidation = int(bonuses.get("intimidation", 0))
	coins += bonuses.get("coins", 0)
	meta_worldwalker = bonuses.get("worldwalker", 0) > 0
	max_health = int(round(stat_vigor * (1.0 + WORLDWALKER_HP_BONUS_PCT))) if meta_worldwalker else stat_vigor
	health = max_health
	attack_damage = int(round(stat_strength * (1.0 + WORLDWALKER_DAMAGE_BONUS_PCT))) if meta_worldwalker else stat_strength
	move_speed = stat_agility
	attack_cooldown_max = max(MIN_ATTACK_COOLDOWN, BASE_ATTACK_COOLDOWN - COOLDOWN_REDUCTION_PER_AGILITY * (stat_agility - AGILITY_START))
	max_stamina = MAX_STAMINA + int(bonuses.get("stamina", 0))
	stamina = max_stamina
	luck_bonus = bonuses.get("luck", 0.0)
	# Resilience/Reflexes/Dexterity themselves stay at 0 until unlocked (see
	# _level_up) -- resilience_reduction/meta_dodge_chance/meta_crit_chance
	# are derived from those stat values in _recalc_stats, not set here.
	meta_resilience_unlocked = bonuses.get("resilience_unlock", 0) > 0
	meta_reflexes_unlocked = bonuses.get("reflexes_unlock", 0) > 0
	meta_dexterity_unlocked = bonuses.get("dexterity_unlock", 0) > 0
	meta_rage_bonus_pct = bonuses.get("rage", 0.0)
	meta_double_hit_chance = bonuses.get("berserker_edge", 0.0)
	meta_lifesteal_pct = bonuses.get("vampiric_grit", 0.0)
	meta_free_specials = bonuses.get("silver_tongue", 0) > 0
	# Not add_healing_item() -- that emits items_changed, which Main.gd
	# forwards to `hud`, and this runs before Main has built the HUD (same
	# reason everything else above avoids its signal-emitting setter too).
	for i in int(bonuses.get("potions", 0)):
		potion_queue.append(ITEM_HEAL_AMOUNT)
	healing_items = potion_queue.size()

	# Skill tree capstones -- one-time unlocks for fully investing in a wing
	# (see SaveData.gd:UPGRADES). Each is now a whole new
	# mechanic rather than a flat stat, so this just sets the flag Main.gd/
	# HUD.gd read; stat_bonus in SaveData.gd is vestigial for these, kept
	# nonzero purely so `bonuses.get(id, 0) > 0` still detects ownership.
	if bonuses.get("battle_hardened", 0) > 0:
		party_members.append({"name": "Blade Ally", "dmg_mult": 0.75})
	has_merchant_prince = bonuses.get("golden_touch", 0) > 0
	has_guardian_skill = bonuses.get("undying", 0) > 0
	# Pack Leader -- a further Warrior-wing unlock past Blade Ally itself, so
	# a fully-invested run can field 2 recruited allies, not just 1. Warlord
	# (deeper still) pushes it one further, to 4.
	if bonuses.get("pack_leader", 0) > 0:
		max_party_slots = 3
	if bonuses.get("warlord", 0) > 0:
		max_party_slots = 4

	# Adrenaline (repurposed): extra damage DEALT below 30% HP, read in
	# Main.gd:_apply_single_hit -- no longer a damage-reduction node.
	meta_low_hp_damage_bonus_pct = bonuses.get("adrenaline", 0.0)
	meta_bonus_coin_pct = bonuses.get("haggling", 0.0)
	meta_healing_bonus_pct = bonuses.get("herbalism", 0.0)
	meta_bonus_levelup_stat = bonuses.get("prodigy", 0) > 0
	# Beastmaster (repurposed): guarantees a Traitor Wolf from the start of
	# the run instead of a bonus recruit-chance -- Main.gd reads party_wolf
	# being non-empty at run start to seed wolf_waves_remaining.
	if bonuses.get("beastmaster", 0) > 0:
		party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	meta_wolf_bonus_waves = int(bonuses.get("pack_bond", 0))
	meta_warband_bonus = bonuses.get("warband", 0.0)
	meta_battle_medic = bonuses.get("battle_medic", 0) > 0
	meta_war_chest_reduction = bonuses.get("war_chest", 0.0)
	meta_war_profiteer_coins = int(bonuses.get("war_profiteer", 0))
	# Appraisal is a plain stacking stat node (extra starting coins), applied
	# the same way its tier-1 counterpart is.
	coins += int(bonuses.get("appraisal", 0))
	# Investor (repurposed): extra weapon slots rolled into every shop
	# offering, read in Main.gd:_roll_shop_offering.
	meta_investor_bonus_slots = int(bonuses.get("investor", 0))
	# Second Wind is a plain stacking stat node too (extra healing items),
	# applied after the base amount above so it adds on top rather than
	# being overwritten by it.
	for i in int(bonuses.get("second_wind", 0)):
		potion_queue.append(ITEM_HEAL_AMOUNT)
	healing_items = potion_queue.size()

	# Block Master / Vigilant Defense (renamed) / Last Stand -- all read
	# directly by Main.gd's damage-reduction/Defend pipeline.
	meta_block_negate_chance = bonuses.get("block_master", 0.0)
	meta_block_heal_amount = int(bonuses.get("vigilant_defense", 0))
	meta_last_stand_pct_per_10 = bonuses.get("last_stand", 0.0)
	meta_shield_block_bonus_pct = bonuses.get("shield_mastery", 0.0)
	meta_shield_universal = bonuses.get("unbreakable_guard", 0) > 0
	meta_riposte_chance = bonuses.get("riposte", 0.0)
	meta_momentum_pct_per_kill = bonuses.get("momentum", 0.0)
	meta_hardened_hp_per_wave = int(bonuses.get("hardened", 0))
	meta_favour_chance = bonuses.get("favour", 0.0)
	meta_stamina_regen_per_turn = int(bonuses.get("second_breath", 0))
	meta_arrow_discount_pct = bonuses.get("fletcher", 0.0)
	# +5 held-arrow cap per level -- read straight off the owned level
	# rather than back-deriving it from the float percentage above (which
	# risks floating-point drift at higher levels).
	meta_arrow_cap_bonus = 5 * int(SaveDataScript.load_data().get("upgrades", {}).get("fletcher", 0))
	meta_field_surgeon_discount_pct = bonuses.get("field_surgeon", 0.0)
	meta_windfall_chance = bonuses.get("windfall", 0.0)
	meta_reroll_discount_pct = bonuses.get("black_market", 0.0)

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	if invincible_timer > 0.0:
		invincible_timer -= delta
	if flash_timer > 0.0:
		flash_timer -= delta

	var move_dir := Vector2.ZERO
	if settings.is_action_pressed("move_up"):
		move_dir.y -= 1
	if settings.is_action_pressed("move_down"):
		move_dir.y += 1
	if settings.is_action_pressed("move_left"):
		move_dir.x -= 1
	if settings.is_action_pressed("move_right"):
		move_dir.x += 1

	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()
		facing = move_dir
		if facing.x != 0.0:
			sprite.flip_h = facing.x < 0.0

	velocity = move_dir * move_speed
	move_and_slide()

	# Isaac-style: WASD aims and swings independently of movement (arrows).
	# Locked for now -- real combat happens in the tile battle; overworld
	# attacking is reserved for a future violent-route mode.
	var attack_dir := Vector2.ZERO
	if not overworld_attack_locked:
		if settings.is_action_pressed("attack_up"):
			attack_dir.y -= 1
		if settings.is_action_pressed("attack_down"):
			attack_dir.y += 1
		if settings.is_action_pressed("attack_left"):
			attack_dir.x -= 1
		if settings.is_action_pressed("attack_right"):
			attack_dir.x += 1

	if attack_dir.length() > 0.0:
		attack_dir = attack_dir.normalized()
		facing = attack_dir
		if facing.x != 0.0:
			sprite.flip_h = facing.x < 0.0
		if cooldown_timer <= 0.0:
			_start_attack()

	if attack_timer > 0.0:
		if current_weapon.shape == "sweep":
			var progress: float = 1.0 - clamp(attack_timer / attack_duration_total, 0.0, 1.0)
			attack_area.rotation = lerp_angle(sweep_start_angle, sweep_end_angle, progress)

		for body in attack_area.get_overlapping_bodies():
			if body != self and not hit_this_swing.has(body) and body.has_method("take_damage"):
				hit_this_swing[body] = true
				_apply_weapon_hit(body)
		attack_timer -= delta

	# A brief red tint (flash_timer) layers under the existing i-frame
	# transparency blink -- distinct cues for "just got hit" vs. "currently
	# can't be hit again," which otherwise look identical.
	var base_color: Color = Color(1.0, 0.4, 0.4) if flash_timer > 0.0 else Color(1.0, 1.0, 1.0)
	if invincible_timer > 0.0 and int(invincible_timer * 12) % 2 == 0:
		sprite.modulate = Color(base_color.r, base_color.g, base_color.b, 0.4)
	else:
		sprite.modulate = base_color

	queue_redraw()

func _apply_weapon_hit(body: Node) -> void:
	var hit_pos: Vector2 = body.global_position
	var main := get_parent()
	var ohko: float = current_weapon.get("ohko_chance", 0.0)
	if ohko > 0.0 and randf() < ohko:
		body.take_damage(99999)
		if main.has_method("spawn_damage_number_world"):
			main.spawn_damage_number_world(hit_pos, 99999)
		return
	var dmg: int = int(round(attack_damage * current_weapon.get("damage_mult", 1.0)))
	body.take_damage(dmg)
	if main.has_method("spawn_damage_number_world"):
		main.spawn_damage_number_world(hit_pos, dmg)
	# Knuckle Gloves' innate double_strike -- every plain swing lands twice.
	# Guarded by is_instance_valid since the first hit may have already
	# killed (and queue_free'd) the target.
	if current_weapon.get("double_strike", false) and is_instance_valid(body):
		body.take_damage(dmg)
		if main.has_method("spawn_damage_number_world"):
			main.spawn_damage_number_world(hit_pos + Vector2(0, -10), dmg)

func _start_attack() -> void:
	attack_duration_total = current_weapon.get("active_duration", 0.15)
	attack_timer = attack_duration_total
	cooldown_timer = max(MIN_ATTACK_COOLDOWN, attack_cooldown_max * current_weapon.get("cooldown_mult", 1.0))
	hit_this_swing.clear()

	match current_weapon.shape:
		"circle":
			attack_area.position = facing * (BODY_RADIUS + current_weapon.offset)
			attack_area.rotation = 0.0
		"sweep":
			var half_angle: float = deg_to_rad(current_weapon.sweep_angle_deg) / 2.0
			sweep_start_angle = facing.angle() - half_angle
			sweep_end_angle = facing.angle() + half_angle
			attack_area.position = facing * (BODY_RADIUS + current_weapon.reach / 2.0)
			attack_area.rotation = sweep_start_angle
		_:
			attack_area.position = facing * (BODY_RADIUS + current_weapon.reach / 2.0)
			attack_area.rotation = facing.angle()

	_play_attack_animation()

# One uniform lunge-and-scale-punch for every weapon shape -- branching the
# animation style per shape (e.g. a rotate for the lone "sweep" weapon,
# Battle Axe) would add real complexity for one weapon's benefit. Timed as a
# fraction of this swing's own active_duration, so a fast dagger flicks
# quicker than a slow greatsword.
func _play_attack_animation() -> void:
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	# A weapon whose cooldown (MIN_ATTACK_COOLDOWN can be as low as 0.12s) is
	# shorter than its own active_duration can re-trigger _start_attack()
	# before the previous swing's tween finished -- snap back to resting
	# state first so a killed mid-flight tween never leaves the sprite stuck
	# lunged/scaled.
	sprite.position = Vector2.ZERO
	sprite.scale = BASE_SPRITE_SCALE

	var lunge_target: Vector2 = facing * ATTACK_LUNGE_DISTANCE
	var scale_target: Vector2 = BASE_SPRITE_SCALE * ATTACK_SCALE_PUNCH
	var out_time: float = attack_duration_total * 0.4
	var return_time: float = attack_duration_total * 0.6

	attack_tween = create_tween()
	attack_tween.set_parallel(true)
	attack_tween.tween_property(sprite, "position", lunge_target, out_time)
	attack_tween.tween_property(sprite, "scale", scale_target, out_time)
	attack_tween.chain().set_parallel(true)
	attack_tween.tween_property(sprite, "position", Vector2.ZERO, return_time)
	attack_tween.tween_property(sprite, "scale", BASE_SPRITE_SCALE, return_time)

func _equip_weapon(weapon: Dictionary) -> void:
	current_weapon_base = weapon
	current_weapon = _apply_meta_passives_to_weapon(_apply_enchantment_to_weapon(weapon))
	match current_weapon.shape:
		"circle":
			var s := CircleShape2D.new()
			s.radius = current_weapon.radius
			attack_collision.shape = s
		_:
			var s := RectangleShape2D.new()
			s.size = Vector2(current_weapon.reach, current_weapon.width)
			attack_collision.shape = s

# Merges the weapon's applied rune (if any) into a duplicate -- damage_mult/
# stamina_cost/break_chance/passive_lifesteal_pct are all read generically
# wherever they already are in the battle code, so only lifesteal needs a
# dedicated flag (passive_lifesteal_pct, the same one a Mythic weapon like
# Stormfang already uses); the rest are plain stat edits applied once here.
func _apply_enchantment_to_weapon(weapon: Dictionary) -> Dictionary:
	var rune_id: String = weapon_enchantments.get(weapon.get("id", ""), "")
	if rune_id == "":
		return weapon
	var rune: Dictionary = EnchantmentsScript.get_rune(rune_id)
	if rune.is_empty():
		return weapon
	var equipped: Dictionary = weapon.duplicate(true)
	var passive: Dictionary = rune.passive
	if passive.has("damage_bonus_pct"):
		equipped.damage_mult *= (1.0 + passive.damage_bonus_pct)
	if passive.has("stamina_discount_pct"):
		for special in equipped.specials:
			special.stamina_cost = int(round(special.stamina_cost * (1.0 - passive.stamina_discount_pct)))
	if passive.has("break_chance_reduction_pct"):
		equipped.break_chance = equipped.get("break_chance", 0.0) * (1.0 - passive.break_chance_reduction_pct)
	if passive.has("lifesteal_pct"):
		equipped.passive_lifesteal_pct = equipped.get("passive_lifesteal_pct", 0.0) + passive.lifesteal_pct
	var slot: int = rune.active_slot
	if slot < equipped.specials.size():
		equipped.specials[slot] = rune.active.duplicate(true)
	return equipped

# Stamps skill-tree passives (account-wide, not tied to any one weapon) onto
# whatever's about to be equipped. Always duplicates first -- the input may
# be the exact same Dictionary as _apply_enchantment_to_weapon's unmodified
# passthrough (no rune -> returns its argument as-is), which itself may be
# WeaponsScript.CLUB, a shared const. Mutating that directly would corrupt
# Club for the rest of the process, not just this Player instance.
func _apply_meta_passives_to_weapon(weapon: Dictionary) -> Dictionary:
	var w := weapon.duplicate(true)
	if meta_double_hit_chance > 0.0:
		w.passive_double_hit_chance = w.get("passive_double_hit_chance", 0.0) + meta_double_hit_chance
	if meta_lifesteal_pct > 0.0:
		w.passive_lifesteal_pct = w.get("passive_lifesteal_pct", 0.0) + meta_lifesteal_pct
	if meta_free_specials:
		w.passive_free_specials = true
	return w

func _shop_discount() -> float:
	return min(0.75, stat_intimidation * 0.01)

func get_weapon_price(weapon: Dictionary) -> int:
	return int(round(weapon.price * (1.0 - _shop_discount())))

func get_owned_tier_rank(base_id: String) -> int:
	var best := -1
	# Mythic deliberately never raises the floor -- it's the single top
	# rank, so counting it here would mean "never offer a downgrade" always
	# resolves to "always Mythic," locking every future shop roll of this
	# weapon type to the ~0.5% jackpot tier forever once you own one.
	for t in WeaponsScript.TIERS:
		if t.tier_name == "Mythic":
			continue
		for m in WeaponsScript.MATERIALS:
			var id: String = "%s_%s_%s" % [base_id, t.tier_name.to_lower(), m.id]
			if owned_weapons.has(id) and t.rank > best:
				best = t.rank
	return best

# Enchants whatever weapon is currently equipped -- there's no general
# "browse every owned weapon" inventory in this game (only the current shop
# offering and whatever's currently equipped are ever full Dictionaries in
# memory), so the Enchant tab only ever targets current_weapon_base. Club is
# excluded since it's the always-free fallback every broken/never-bought
# weapon reverts to.
func try_apply_enchantment(rune_id: String) -> bool:
	var weapon_id: String = current_weapon_base.get("id", "")
	if weapon_id == "" or weapon_id == "club":
		return false
	if weapon_enchantments.has(weapon_id):
		return false
	var rune: Dictionary = EnchantmentsScript.get_rune(rune_id)
	if rune.is_empty():
		return false
	if runic_shards < rune.cost_shards or coins < rune.cost_coins:
		return false
	runic_shards -= rune.cost_shards
	runic_shards_changed.emit(runic_shards)
	coins -= rune.cost_coins
	coins_changed.emit(coins)
	weapon_enchantments[weapon_id] = rune_id
	_equip_weapon(current_weapon_base)
	return true

func try_buy_weapon(weapon: Dictionary) -> bool:
	# Might gate: Masterwork/Legendary/Mythic (and anything else tagged with
	# a required_might above 0) can't be bought OR re-equipped below the
	# threshold -- same hard block whether this is a fresh purchase or
	# switching back to something already owned.
	if int(weapon.get("required_might", 0)) > stat_might:
		return false
	var id: String = weapon.id
	if owned_weapons.has(id):
		_equip_weapon(weapon)
		return true
	var price := get_weapon_price(weapon)
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	owned_weapons[id] = true
	_equip_weapon(weapon)
	return true

func get_armor_price(armor: Dictionary) -> int:
	return int(round(armor.price * (1.0 - _shop_discount())))

func try_buy_armor(armor: Dictionary) -> bool:
	var id: String = armor.id
	if owned_armor.has(id):
		equipped_armor = armor
		return true
	var price := get_armor_price(armor)
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	owned_armor[id] = true
	equipped_armor = armor
	return true

func get_shield_price(shield: Dictionary) -> int:
	return int(round(shield.price * (1.0 - _shop_discount())))

func try_buy_shield(shield: Dictionary) -> bool:
	var id: String = shield.id
	if owned_shields.has(id):
		equipped_shield = shield
		return true
	var price := get_shield_price(shield)
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	owned_shields[id] = true
	equipped_shield = shield
	return true

# Weapon-compat gate shared by every shield helper below -- normally just
# Shields.COMPATIBLE_WEAPONS, but the Unbreakable Guard capstone
# (meta_shield_universal) waives it entirely so a shield stays active on
# two-handed weapons too.
func _shield_weapon_ok() -> bool:
	return meta_shield_universal or ShieldsScript.is_weapon_compatible(current_weapon.get("id", ""))

# Flat -- identical with ANY compatible weapon equipped, not just the
# shield's own synergy_weapon (only the special's power scales with synergy,
# see shield_special_pct()). Inert (0.0) whenever no shield is carried or the
# current weapon needs both hands -- see Shields.COMPATIBLE_WEAPONS. The
# Shield Mastery skill node adds a flat bonus on top of the shield's own rate.
func shield_block_chance() -> float:
	if berserk_turns_remaining > 0:
		return 0.0
	if equipped_shield.is_empty() or not _shield_weapon_ok():
		return 0.0
	return equipped_shield.get("block_chance", 0.0) + meta_shield_block_bonus_pct

# Heavy Shield's passive: immune to forced repositioning (water push) while
# raised. Same weapon-compat gating as shield_block_chance().
func shield_push_immune() -> bool:
	if equipped_shield.is_empty() or not _shield_weapon_ok():
		return false
	return equipped_shield.get("push_immune", false)

# Phantom Guard's "evasive": true whenever a dodge should offer a reposition
# choice (Main.gd:_enemy_apply_damage), regardless of what actually caused
# the dodge to succeed.
func shield_evasion_active() -> bool:
	if equipped_shield.is_empty() or equipped_shield.get("special", "") != "evasive":
		return false
	return _shield_weapon_ok()

# How many tiles the player may relocate during an evasion reposition --
# special_pct/synergy_special_pct are step counts for this one special,
# reusing the same base/synergy split every other shield special power uses.
func shield_evasion_steps() -> int:
	if not shield_evasion_active():
		return 0
	return int(shield_special_pct())

# The shield special's power (parry/thorns/vengeance) once a block has
# already succeeded -- distinct from shield_block_chance() above, which is
# the ROLL to trigger a block in the first place.
func shield_special_pct() -> float:
	if equipped_shield.is_empty():
		return 0.0
	if current_weapon.get("id", "") == equipped_shield.get("synergy_weapon", ""):
		return equipped_shield.get("synergy_special_pct", 0.0)
	return equipped_shield.get("special_pct", 0.0)

func get_potion_price(potion: Dictionary) -> int:
	return int(round(potion.price * (1.0 - _shop_discount()) * (1.0 - meta_field_surgeon_discount_pct)))

func try_buy_potion(potion: Dictionary) -> bool:
	var price := get_potion_price(potion)
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	add_potion(potion.heal_amount)
	return true

# Scales with how many of that type are CURRENTLY held, not a lifetime
# purchase count -- selling some back down brings the next buy's price back
# down too, per the user's answer on how this should escalate.
func get_arrow_price(kind: String) -> int:
	var base_price: int = WeaponsScript.ARROW_TYPES[kind].price
	var held: int = owned_arrows.get(kind, 0)
	var scaled: float = base_price * pow(WeaponsScript.ARROW_PRICE_GROWTH, held)
	return int(round(scaled * (1.0 - _shop_discount()) * (1.0 - meta_arrow_discount_pct)))

func try_buy_arrow(kind: String) -> bool:
	if not owned_arrows.has(kind) or owned_arrows[kind] >= WeaponsScript.ARROW_MAX_HELD + meta_arrow_cap_bonus:
		return false
	var price := get_arrow_price(kind)
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	owned_arrows[kind] += 1
	return true

func try_sell_arrow(kind: String) -> bool:
	if not owned_arrows.has(kind) or owned_arrows[kind] <= 0:
		return false
	owned_arrows[kind] -= 1
	coins += WeaponsScript.ARROW_SELL_PRICE
	coins_changed.emit(coins)
	return true

func add_coins(amount: int) -> void:
	var bonus_amount := amount
	if meta_bonus_coin_pct > 0.0:
		bonus_amount = int(round(amount * (1.0 + meta_bonus_coin_pct)))
	coins += bonus_amount
	coins_changed.emit(coins)

func try_spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func add_runic_shards(amount: int) -> void:
	runic_shards += amount
	runic_shards_changed.emit(runic_shards)

func try_spend_runic_shards(amount: int) -> bool:
	if runic_shards < amount:
		return false
	runic_shards -= amount
	runic_shards_changed.emit(runic_shards)
	return true

func heal(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)
	health_changed.emit(health, max_health)

# Sets health to an exact snapshot value rather than a delta -- used to undo
# a pending move (e.g. cliff-fall damage) that hasn't been locked in yet.
func restore_health(amount: int) -> void:
	health = clampi(amount, 0, max_health)
	health_changed.emit(health, max_health)

func reset_stamina() -> void:
	stamina = max_stamina
	exhausted = false
	stamina_changed.emit(stamina, max_stamina)

func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	if stamina <= 0:
		exhausted = true
	stamina_changed.emit(stamina, max_stamina)
	return true

func regen_stamina(amount: int) -> void:
	var gain: int = amount
	if exhausted:
		gain = int(round(amount * EXHAUSTED_STAMINA_REGEN_MULT))
	stamina = clampi(stamina + gain, 0, max_stamina)
	if exhausted and float(stamina) >= float(max_stamina) * EXHAUSTED_CLEAR_STAMINA_PCT:
		exhausted = false
	stamina_changed.emit(stamina, max_stamina)

func add_potion(heal_amount: int) -> void:
	potion_queue.append(heal_amount)
	healing_items = potion_queue.size()
	items_changed.emit(healing_items)

func add_healing_item(count: int = 1) -> void:
	for i in count:
		add_potion(ITEM_HEAL_AMOUNT)

# Returns the amount healed, or -1 if there were no potions to use.
func use_healing_item() -> int:
	if potion_queue.is_empty():
		return -1
	var heal_amount: int = potion_queue.pop_front()
	if meta_healing_bonus_pct > 0.0:
		heal_amount = int(round(heal_amount * (1.0 + meta_healing_bonus_pct)))
	healing_items = potion_queue.size()
	items_changed.emit(healing_items)
	heal(heal_amount)
	# Battle Medic (Survivor + Warrior convergence): every healing item also
	# restores a flat chunk of stamina.
	if meta_battle_medic:
		regen_stamina(20)
	return heal_amount

func take_damage(amount: int) -> void:
	if invincible_timer > 0.0:
		return
	health -= amount
	invincible_timer = INVINCIBILITY_TIME
	flash_timer = FLASH_DURATION
	var main := get_parent()
	if main.has_method("spawn_damage_number_world"):
		main.spawn_damage_number_world(global_position, amount)
	if main.has_method("notify_camera_shake"):
		main.notify_camera_shake(6.0, 0.2)
	# Clamp before emitting, same reasoning as take_battle_damage -- nothing
	# re-emits after the clamp below, so an unclamped emit here would leave
	# the HUD stuck showing a negative HP value on death.
	if health <= 0:
		health = 0
		health_changed.emit(health, max_health)
		died.emit()
	else:
		health_changed.emit(health, max_health)

# Turn-based battle damage (enemy hits, cliff falls) is not subject to the
# overworld's real-time invincibility frames -- each turn is a discrete
# decision, not a rapid repeated collision, so i-frames don't apply here.
func take_battle_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		# Favour (renamed from Second Chance): a %-chance, the first time a
		# hit would drop you to 0 HP each battle, to survive with 1 HP
		# instead -- consumed here, reset by Main.gd:_setup_battle_grid at
		# the start of every fight.
		if meta_favour_chance > 0.0 and randf() < meta_favour_chance and not second_chance_used_this_battle:
			second_chance_used_this_battle = true
			health = 1
			health_changed.emit(health, max_health)
			return
		# Clamp before emitting -- otherwise the HUD gets the raw negative
		# value first and, since nothing re-emits after the clamp below,
		# is stuck showing e.g. "-4 / 10" instead of "0 / 10" on death.
		health = 0
		health_changed.emit(health, max_health)
		died.emit()
	else:
		health_changed.emit(health, max_health)

func gain_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while xp >= xp_to_next and level < MAX_LEVEL:
		xp -= xp_to_next
		_level_up()
	xp_changed.emit(xp, xp_to_next)

func _level_up() -> void:
	level += 1
	stat_intimidation += 1
	stat_strength += 1
	stat_vigor += 1
	stat_agility += 1
	stat_might += 1
	# Resilience/Reflexes/Dexterity only join the auto-+1 once their
	# skill-tree unlock node is owned -- before that they stay at 0 and
	# never appear on the level-up choice screen (see HUD.gd:
	# show_levelup_choice).
	if meta_resilience_unlocked:
		stat_resilience += 1
	if meta_reflexes_unlocked:
		stat_reflexes += 1
	if meta_dexterity_unlocked:
		stat_dexterity += 1
	if level >= MAX_LEVEL:
		xp = 0
		xp_to_next = 0
	else:
		xp_to_next = XP_BASE + XP_PER_LEVEL * level
	_recalc_stats()
	awaiting_bonus = true
	leveled_up.emit(level)

func apply_bonus_stat(stat_name: String) -> void:
	# Prodigy: the chosen stat is applied twice instead of once. Brawn/
	# Swiftness/Vitality/Presence (meta_levelup_bonus_*) add straight onto
	# the base +1 (or +AGILITY_BONUS_PER_LEVEL for agility) BEFORE Prodigy's
	# doubling, so both stack multiplicatively with each other -- e.g. Brawn
	# level 2 + Prodigy turns "+1 Strength" into "+3", then Prodigy doubles
	# that whole result to "+6". Might/Resilience/Reflexes/Dexterity have no
	# equivalent skill-tree amplifier yet, so they just get the doubling.
	var times := 2 if meta_bonus_levelup_stat else 1
	for i in times:
		match stat_name:
			"intimidation":
				stat_intimidation += 1 + meta_levelup_bonus_intimidation
			"strength":
				stat_strength += 1 + meta_levelup_bonus_strength
			"vigor":
				stat_vigor += 1 + meta_levelup_bonus_vigor
			"agility":
				stat_agility += AGILITY_BONUS_PER_LEVEL + meta_levelup_bonus_agility
			"might":
				stat_might += 1
			"resilience":
				stat_resilience += 1
			"reflexes":
				stat_reflexes += 1
			"dexterity":
				stat_dexterity += 1
	awaiting_bonus = false
	_recalc_stats()

func _recalc_stats() -> void:
	var old_max := max_health
	max_health = int(round(stat_vigor * (1.0 + WORLDWALKER_HP_BONUS_PCT))) if meta_worldwalker else stat_vigor
	health += max_health - old_max
	health = clampi(health, 0, max_health)
	attack_damage = int(round(stat_strength * (1.0 + WORLDWALKER_DAMAGE_BONUS_PCT))) if meta_worldwalker else stat_strength
	move_speed = stat_agility
	attack_cooldown_max = max(MIN_ATTACK_COOLDOWN, BASE_ATTACK_COOLDOWN - COOLDOWN_REDUCTION_PER_AGILITY * (stat_agility - AGILITY_START))
	resilience_reduction = min(RESILIENCE_REDUCTION_CAP, stat_resilience * RESILIENCE_PCT_PER_POINT)
	meta_dodge_chance = min(REFLEXES_DODGE_CAP, stat_reflexes * REFLEXES_PCT_PER_POINT)
	meta_crit_chance = min(DEXTERITY_CRIT_CAP, stat_dexterity * DEXTERITY_PCT_PER_POINT)
	health_changed.emit(health, max_health)
	stats_changed.emit(stat_intimidation, stat_strength, stat_vigor, stat_agility, stat_might)

func _draw() -> void:
	if attack_timer <= 0.0:
		return
	if current_weapon.shape == "circle":
		draw_set_transform(attack_area.position, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, current_weapon.radius, 0, TAU, 24, Color(1.0, 1.0, 0.2, 0.5), 3.0)
	else:
		draw_set_transform(attack_area.position, attack_area.rotation, Vector2.ONE)
		var reach: float = current_weapon.reach
		var width: float = current_weapon.width
		draw_rect(Rect2(-reach / 2.0, -width / 2.0, reach, width), Color(1.0, 1.0, 0.2, 0.5))
