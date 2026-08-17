extends Node2D

const PlayerScript := preload("res://scripts/Player.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const OrcScript := preload("res://scripts/Orc.gd")
const BossScript := preload("res://scripts/Boss.gd")
const ArcherScript := preload("res://scripts/Archer.gd")
const ShamanScript := preload("res://scripts/Shaman.gd")
const BruteScript := preload("res://scripts/Brute.gd")
const ShadeScript := preload("res://scripts/Shade.gd")
const WolfScript := preload("res://scripts/Wolf.gd")
const OwlbearScript := preload("res://scripts/Owlbear.gd")
const CentaurScript := preload("res://scripts/Centaur.gd")
const FaeHutScript := preload("res://scripts/FaeHut.gd")
const FaeScript := preload("res://scripts/Fae.gd")
const GnomeScript := preload("res://scripts/Gnome.gd")
const DruidScript := preload("res://scripts/Druid.gd")
const AbolethScript := preload("res://scripts/Aboleth.gd")
const WaterElementalScript := preload("res://scripts/WaterElemental.gd")
const LizardSoldierSwarmScript := preload("res://scripts/LizardSoldierSwarm.gd")
const BlackDragonletScript := preload("res://scripts/BlackDragonlet.gd")
const TreantScript := preload("res://scripts/Treant.gd")
const ElderOakScript := preload("res://scripts/ElderOak.gd")
const GibberingMoutherScript := preload("res://scripts/GibberingMouther.gd")
const IronGolemScript := preload("res://scripts/IronGolem.gd")
const StoneGiantScript := preload("res://scripts/StoneGiant.gd")
const BeholderScript := preload("res://scripts/Beholder.gd")
const FrostGiantScript := preload("res://scripts/FrostGiant.gd")
const WhiteDragonScript := preload("res://scripts/WhiteDragon.gd")
const RocScript := preload("res://scripts/Roc.gd")
const BlueDragonScript := preload("res://scripts/BlueDragon.gd")
const LavaGolemScript := preload("res://scripts/LavaGolem.gd")
const RedWyrmScript := preload("res://scripts/RedWyrm.gd")
const VoidwingScript := preload("res://scripts/Voidwing.gd")
const SupremeWarlockScript := preload("res://scripts/SupremeWarlock.gd")
const DemogorgonScript := preload("res://scripts/Demogorgon.gd")
const TiamatScript := preload("res://scripts/Tiamat.gd")
const CountStrahdScript := preload("res://scripts/CountStrahd.gd")
const DukeZaltoScript := preload("res://scripts/DukeZalto.gd")
const AcererakScript := preload("res://scripts/Acererak.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const SfxScript := preload("res://scripts/Sfx.gd")
const EventsScript := preload("res://scripts/Events.gd")

# Phantom Guard's "evasive" special: fired the instant its reposition choice
# is locked in (an explicit Confirm press, or evasion_steps_left running
# out) -- see _prompt_evasion_reposition/_try_evasion_step.
signal evasion_confirmed

const SFX_POOL_SIZE := 6

const WORLD_SIZE := Vector2(700, 500)
# Purely visual overworld scatter -- no collision, so it can't ever
# accidentally box the player or an enemy in the way rock terrain can in a
# tile battle.
const DECO_TREE_COUNT := 8
const DECO_BUSH_COUNT := 10
const DECO_GRASS_TUFT_COUNT := 14
const DECO_MIN_SPACING := 34.0
const DECO_PLAYER_CLEARANCE := 70.0
const ENEMY_COUNT := 6
const ORC_COUNT := 2
# Rejection-sampled away from the player at spawn time, same idea as
# DECO_PLAYER_CLEARANCE -- without this, a random roll can occasionally land
# an enemy within Enemy.CONTACT_RANGE of the player and force an immediate,
# unavoidable battle the instant a wave starts.
const ENEMY_SPAWN_CLEARANCE := 100.0
# Every 5th wave is a solo boss fight instead of the usual goblin/orc mix.
const BOSS_WAVE_INTERVAL := 5
# Waves 1-100 are 10 themed worlds (WORLDS below) of 10 waves each; wave 101+
# is world index 10, the Nothingness boss rush (see _spawn_nothingness_fight).
const WAVES_PER_WORLD := 10
# Kept as its own named constant (rather than inlining WAVES_PER_WORLD) since
# a couple of tests read it directly to mean "Plains' own boss wave" --
# _spawn_boss_wave itself no longer branches on this at all, it reads
# WORLDS[current_world_index].boss_script generically (Plains' boss_script
# happens to be Owlbear, same as always).
const OWLBEAR_WAVE_START := WAVES_PER_WORLD
# New enemy types phase in gradually rather than all at once, so each wave
# introduces one new wrinkle instead of overwhelming a fresh run immediately.
const ARCHER_WAVE_START := 1
const SHAMAN_WAVE_START := 2
const BRUTE_WAVE_START := 3
const SHADE_WAVE_START := 4
const WOLF_WAVE_START := 2
const CENTAUR_WAVE_START := 7
const CENTAUR_PACK_SIZE := 3
const FAE_HUT_WAVE_START := 3
const GNOME_WAVE_START := 2
const GNOME_PACK_SIZE_MAX := 5
const DRUID_WAVE_START := 5

const DEFAULT_BATTLE_GRID_SIZE := 8
const BOSS_BATTLE_GRID_SIZE := 15
# Not const: a boss fight (see _setup_battle_grid) sizes these up to
# BOSS_BATTLE_GRID_SIZE for the duration of that battle. Every read site
# already references these symbolically rather than a literal default, so
# this is the only place that needs to know a boss fight is bigger.
var BATTLE_GRID_W := DEFAULT_BATTLE_GRID_SIZE
var BATTLE_GRID_H := DEFAULT_BATTLE_GRID_SIZE
# Goblin-tier battles (weak/support types mixed in) stay small; "tough"
# battles (Orc, Brute, Shade) are the bigger, harder set-piece fights,
# guaranteed at least one tough unit (the one you engaged).
const MAX_BATTLE_ENEMIES_GOBLIN := 2
const MAX_BATTLE_ENEMIES_TOUGH := 4
const MAX_BATTLE_TOUGH_UNITS := 2
# The overall party-size ceiling _gather_squad's computed max_enemies can
# never exceed, regardless of how big _squad_size_bonus gets -- up from the
# old flat MAX_BATTLE_ENEMIES_TOUGH=4 hard cap.
const MAX_BATTLE_SQUAD_SIZE_CEILING := 6
const BATTLE_GATHER_RADIUS := 200.0
const CLIFF_FALL_DAMAGE_PCT := 0.05
const ROCK_COVER_REDUCTION := 0.25
const DEFEND_DAMAGE_REDUCTION := 0.3
# Might: +0.5% ally (recruited party member/wolf) damage per point owned,
# see _place_ally_units.
const MIGHT_ALLY_DAMAGE_PCT_PER_POINT := 0.005
# Squad coordination: two valid targets (player, a living ally) within this
# many tiles of each other count as a "genuine tie" for _assign_enemy_targets
# to split enemies across, rather than everyone converging on whichever one
# is marginally closer.
const TARGET_DECONFLICT_TOLERANCE := 1
# Riposte (deep Warrior node): a counter-attack triggered by a Precision
# dodge, dealt at this fraction of a normal hit.
const RIPOSTE_DAMAGE_PCT := 0.5
const BATTLE_FLEE_COOLDOWN := 2.0
# Orcs (and Bosses) telegraph before they hit, same as their overworld
# windup -- they skip a turn to wind up, then land a heavier blow next turn
# if still in range. Goblins have no telegraph and just swing every turn
# they're in range, but hit for less and have far less HP -- that contrast
# IS their identity.
const ORC_WINDUP_DAMAGE_MULT := 2.0
const CARDINAL_DIRS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

# Reserved terrain types -- fully implemented (movement/damage/status
# mechanics in _resolve_battle_step/_apply_terrain_tick/_apply_knockback,
# icons in HUD.gd) but never rolled by _setup_battle_grid's _place_terrain
# calls, which only ever generate rock/water/ledge/cliff. Held back until a
# future "world" system (a volcano map, a beach map, etc.) can pick which of
# these fit a given battlefield, instead of every battle rolling from all of
# them indiscriminately regardless of setting.
const RESERVED_TERRAIN_TYPES := ["ice", "embers", "poison_bog", "quicksand", "spring", "crumbling", "thicket", "caltrops", "rubble"]
# Poison: %-of-max-HP per turn (both sides), replacing the old flat 6
# damage/3 turns. Computed from the target's max HP at application time
# (Poison Bog tick, below), not a flat const.
const POISON_TURNS := 5
const POISON_DAMAGE_PCT := 0.10
# Burn: %-of-max-HP per turn AND -25% damage DEALT while active, with no
# natural duration at all -- the only thing that clears it is standing on a
# "water" terrain tile (see _apply_water_push). Both Embers terrain and
# Flame Arrow inflict this same status now, replacing Embers' old one-off
# flat hit and Flame Arrow's old flat-duration burn.
const BURN_DAMAGE_DIVISOR := 15
const BURN_DAMAGE_DEALT_REDUCTION := 0.25
# Bleeding: inflicted by ENEMY_TRAITS["inflicts_bleed"] on a landed hit
# against the player (guaranteed, no roll), no natural duration -- lasts the
# rest of the battle (cleared in the same per-battle reset every other
# battle-scoped player status uses). %-of-max-HP, not flat, same as
# Poison/Burn above.
const BLEED_MOVE_DAMAGE_PCT := 0.05
const BLEED_DODGE_DAMAGE_PCT := 0.10
# Blindness: inflicted by ENEMY_TRAITS["inflicts_blind"] on a landed hit,
# lasts a fixed number of turns like Concussion/Frozen. While active, the
# player's own attacks have a high miss chance, but anything that lands is
# an automatic crit (reuses the Dexterity crit path from Part 1).
const BLINDNESS_TURNS := 2
const BLINDNESS_MISS_CHANCE := 0.75
# Exhausted lives entirely in Player.gd (EXHAUSTED_STAMINA_REGEN_MULT/
# EXHAUSTED_CLEAR_STAMINA_PCT there) -- self-inflicted the instant stamina
# hits 0, no enemy source or battle-state tracking needed here.
# Rage/Berserk: triggered by a kill mid-battle (_on_enemy_died), the state
# itself (berserk_turns_remaining) lives on Player.gd since it's checked
# from several unrelated call sites, but the tuning numbers stay here with
# every other status const. +50% damage dealt on top of Rage's own
# meta_rage_bonus_pct; shields forced off entirely (Player.gd:
# shield_block_chance); Block Master and Reflexes dodge both cut to a
# quarter of their normal rate.
const BERSERK_TURNS := 2
const BERSERK_DAMAGE_BONUS_PCT := 0.5
const BERSERK_DEFENSE_MULT := 0.25
# Vulnerable: a landed player crit (_apply_single_hit) marks the target,
# increasing ALL damage it takes -- player's and every ally's, since they
# all funnel through the same function -- for a few turns. "Focus this
# target down" once you've found the opening.
const VULNERABLE_TURNS := 2
const VULNERABLE_DAMAGE_TAKEN_BONUS_PCT := 0.25
# Detection is always on, every battle: a non-boss enemy starts every fight
# UNAWARE and only targets the player once it's actually spotted them --
# close enough (see ENEMY_SIGHT_RANGE/STEALTH_SIGHT_RANGE below) with clear
# line of sight (_has_line_of_sight). Once spotted, a unit's awareness
# (battle_units' "aware_of_player" field) is sticky for the rest of the
# battle -- see _update_enemy_awareness/_enemy_currently_sees_player.
# Unaware units fall back to a living ally if one exists, otherwise wander
# (see _move_enemy_wander). Boss-tier enemies are always aware, and Taunt
# reveals the player to every unit immediately regardless of range/LOS.
#
# Manhattan distance a normal (non-stealthed) enemy can spot the player
# within.
const ENEMY_SIGHT_RANGE := 4
# Stealth: while active, SHRINKS the detection range above to this instead
# (already-aware units stay aware -- Stealth only helps you avoid being
# newly spotted, it doesn't un-alert anyone already onto you). The player's
# own next attack breaks stealth immediately and is a guaranteed crit
# (stealth_forced_crit, same mechanism as Blindness's own forced crit in
# _apply_single_hit).
const STEALTH_TURNS := 3
const STEALTH_STAMINA_COST := 20
const STEALTH_SIGHT_RANGE := 2
# Wandering (no visible target -- see _move_enemy_wander) throttles a fast
# unit's movement budget down to this; slower units are unaffected since
# min() only ever lowers a larger value.
const WANDER_MOVE_RANGE_CAP := 2
# Dagger-specific: a crit landed on an enemy that doesn't currently see the
# player (see _enemy_currently_sees_player) deals this much extra flat
# damage -- see _apply_single_hit.
const KNIFE_STEALTH_CRIT_BONUS := 30
const SPRING_HEAL_AMOUNT := 15
# Rubble crumbling away entirely (instead of stunning like Rock) when
# something's knocked into it -- see _apply_knockback.
const RUBBLE_CRUMBLE_CHANCE := 0.4
# Party members' battle-time HP is derived fresh from the player's CURRENT
# max_health every battle (see _setup_battle_grid) rather than stored on the
# permanent roster -- so it scales with Vitality upgrades automatically, and
# a KO'd ally is battle-scoped only (full HP again next fight) for free.
const ALLY_MAX_HP_PCT := 0.7
const WOLF_ALLY_MAX_HP_PCT := 0.55
const ALLY_MOVE_RANGE := 2
const ALLY_WOLF_MOVE_RANGE := 3
const ALLY_ATTACK_RANGE := 1

# A landed hit shoves the target one tile straight back from the attacker,
# turning terrain into something you can use offensively instead of just
# a passive hazard: knock them into a rock and they're stunned, off a cliff
# and they take fall damage. Orcs are bulky enough to shrug it off sometimes;
# goblins always go flying. Bosses are too heavy to ever be moved at all.
const ORC_KNOCKBACK_RESIST_CHANCE := 0.5
const BRUTE_KNOCKBACK_RESIST_CHANCE := 0.6

# Bosses hit noticeably harder once wounded -- a last-stretch danger spike
# mirroring the player's own "execute" specials (finish them before they
# finish you).
const BOSS_ENRAGE_HP_THRESHOLD := 0.3
const BOSS_ENRAGE_DAMAGE_MULT := 1.5

# Shamans heal their worst-hurt ally instead of attacking whenever one needs
# it, so a squad built around one becomes a "kill the healer first" puzzle
# instead of just more HP to chew through.
const SHAMAN_HEAL_PCT := 0.25

# Goblins hit harder while another goblin still fights alongside them --
# "safety in numbers" gives the weakest enemy an identity beyond filler, and
# rewards thinning a goblin swarm down instead of ignoring the stragglers.
const GOBLIN_PACK_DAMAGE_MULT := 1.5

# Gnomes take this further than a Goblin's binary pack bonus -- both HP and
# damage scale continuously with how many packmates are around. HP is a
# one-time snapshot at battle setup (how big the pack started), damage is
# recomputed live every turn (how many are STILL alive right now), so
# thinning a Gnome mob down visibly softens the survivors' punch turn by
# turn instead of just removing bodies.
const GNOME_HP_PER_PACKMATE := 2
const GNOME_DAMAGE_PCT_PER_PACKMATE := 0.2

# A Fae Hut spawns a fresh Fae into the fight every this-many of its own
# turns (see _process_enemy_turn's spawns_fae branch) -- it never attacks on
# its own, so leaving it up is a ticking clock, not a passive threat.
const FAE_HUT_SPAWN_INTERVAL := 3

# Druid: heals like a Shaman when someone's hurt, otherwise buffs an
# un-buffed ally's damage for a few turns instead of attacking -- only
# fights directly once no ally needs either and it's the last one standing.
const DRUID_BUFF_DMG_PCT := 0.3
const DRUID_BUFF_TURNS := 3

# A dagger special heals the player for a cut of the damage it just dealt.
const LIFESTEAL_PCT := 0.5
# Club's Second Wind: a flat heal based on max HP, regardless of damage dealt.
const SELF_HEAL_PCT := 0.2
# Spear's Target Practice: an instakill coin-flip, not a normal damage hit.
const TARGET_PRACTICE_CHANCE := 0.3
const TARGET_PRACTICE_BOSS_CHANCE := 0.05
# Greatsword's Low Sweep: chance its move_range-halving actually lands.
const LOW_SWEEP_CHANCE := 0.8
# War Hammer's Maracas: bonus multiplier vs. an armored target.
const MARACAS_ARMORED_MULT := 1.5
# War Hammer's BONK: how many turns Concussed lasts.
const BONK_CONCUSSED_TURNS := 3
# Player-side Concussion (distinct from BONK above, which only ever hits
# enemies): inflicted by blunt-wielding enemies (ENEMY_TRAITS["inflicts_
# concussion"]) on a successful hit against the player. Once active, it's a
# 50% chance/turn to take damage equal to the player's own Might stat, for
# 2 turns -- CONCUSSION_INFLICT_CHANCE (whether a blunt hit applies the
# status at all) is a separate roll from PLAYER_CONCUSSION_CHANCE (whether
# an active status actually hurts this turn); they coincide at 0.5 today but
# aren't the same knob.
const PLAYER_CONCUSSION_TURNS := 2
const PLAYER_CONCUSSION_CHANCE := 0.5
const CONCUSSION_INFLICT_CHANCE := 0.5
# Hand Picks' Pichaku: battle-long damage multiplier and extra-hit chance on
# every regular/heavy attack (effect == "" is what distinguishes those two
# from every named special).
const PICHAKU_DAMAGE_MULT := 0.8
const PICHAKU_DOUBLE_HIT_CHANCE := 0.2

# Special arrows (Bow-only, see WeaponsScript.ARROW_TYPES) -- flat damage
# numbers, not scaled by weapon damage_mult like a normal hit.
const ARROW_FLAME_FLAT_DMG := 2
const ARROW_FLAME_DMG_STAT_PCT := 0.5
const ARROW_FREEZE_FLAT_DMG := 5
const ARROW_FREEZE_MIN_TURNS := 2
const ARROW_FREEZE_MAX_TURNS := 4
const ARROW_BOMB_FLAT_DMG := 20
# Chebyshev radius, not the Manhattan _footprint_dist used elsewhere -- 1
# gives the full 3x3 block (including diagonal corners) the arrow's
# description promises, not the plus-shaped 5-tile area Manhattan would.
const ARROW_BOMB_RADIUS := 1

# Orcs sometimes skip the telegraph entirely for a quick, weak jab instead --
# you can no longer assume "not winding up yet" means a free turn.
const ORC_QUICK_JAB_CHANCE := 0.4

# The Apprentice Mage (Archer.gd's display name/identity, reworked) hits
# from 4 tiles off on any line, not just a straight one -- see ignore_line
# on _can_battle_attack.
const ARCHER_ATTACK_RANGE := 4
# The Centaur Archer variant keeps the original Archer's straight-line
# kiting identity, at a shorter range than the Apprentice Mage now has.
const CENTAUR_ARCHER_ATTACK_RANGE := 3

# A Shade has only 1 HP (see Shade.gd) -- this is its entire defense.
const SHADE_DODGE_CHANCE := 0.4

# Each non-default enemy type's tile-battle combat identity, looked up by
# display name -- adding a new type's gimmick is a data entry here instead of
# another name check scattered through the turn logic below. Anything absent
# gets the all-default profile: fast 2-tile move, 1x1, melee-only, no
# telegraph, no special resistances.
const ENEMY_TRAITS := {
	# Hits harder whenever another goblin is still alive in the same fight.
	# "Persistent" (never loses aggro once it spots you) lives in Enemy.gd,
	# not here, since that's an overworld-chase behavior, not a battle one.
	"Goblin": {"pack_bonus_mult": GOBLIN_PACK_DAMAGE_MULT},
	# Tries to flank around the player toward the nearest edge instead of
	# charging straight in (see _flank_target_tile), and sometimes skips its
	# telegraph for an immediate weak jab instead of the big windup hit.
	"Orc": {"windup": true, "knockback_resist": ORC_KNOCKBACK_RESIST_CHANCE, "move_range": 1, "big_squad": true, "corners": true, "quick_jab_chance": ORC_QUICK_JAB_CHANCE, "armored": true, "inflicts_concussion": true},
	"Boss": {"windup": true, "knockback_resist": 1.0, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "armored": true, "is_boss_tier": true},
	# From OWLBEAR_WAVE_START on, replaces Boss as the wave-boss. A full 2x2
	# footprint that ignores every terrain rule (like the Brute) and corners
	# the player the same way the Orc's flank-tile steering does (like the
	# Orc, extended to 2x2 units -- see _move_big_unit), plus a sweeping
	# attack that can hit the player AND an adjacent ally in the same swing
	# (see "sweeps", _sweep_targets).
	"Owlbear": {"size": 2, "ignore_terrain": true, "ignore_cover": true, "knockback_resist": 0.8, "corners": true, "sweeps": true, "move_range": 1, "armored": true, "is_boss_tier": true},
	# Reworked from the original Archer: shorter range than before but no
	# longer needs a straight line to its target (see ignore_line on
	# _can_battle_attack) -- a caster's arcing bolt instead of a bowstring's
	# dead-straight shot. Doesn't kite/strafe -- that identity moved to the
	# Centaur Archer variant below, so the two ranged enemies feel distinct.
	"Apprentice Mage": {"attack_range": ARCHER_ATTACK_RANGE, "ignore_line": true, "inflicts_blind": true, "inflicts_fear": true},
	# Heals its worst-hurt living ally instead of attacking whenever one
	# exists, and refuses to engage directly at all while any other ally is
	# still standing -- only fights once it's truly the last one left.
	"Shaman": {"heals_allies": true},
	# A full 2x2 footprint (see the "size" field in _setup_battle_grid) that
	# ignores every terrain rule entirely -- rocks, water, ledges, cliffs all
	# do nothing to it -- on top of shrugging off rock cover and resisting
	# knockback harder than an Orc.
	"Brute": {"ignore_cover": true, "ignore_terrain": true, "knockback_resist": BRUTE_KNOCKBACK_RESIST_CHANCE, "move_range": 1, "big_squad": true, "size": 2, "armored": true},
	# Fastest thing on the grid, but a single hit that actually lands is
	# always lethal (1 HP) -- its only defense is a real chance to dodge
	# entirely instead of soaking the hit.
	"Shade": {"move_range": 3, "big_squad": true, "dodge_chance": SHADE_DODGE_CHANCE, "inflicts_fear": true},
	# Fast mobility on the grid, same as Shade, but no dodge chance and no
	# big-squad flag -- a Traitor Wolf is combat-identical, just a rarer
	# named spawn (see Wolf.gd/_spawn_enemies) with a shot at recruitment on
	# death instead.
	"Wolf": {"move_range": 3},
	"Traitor Wolf": {"move_range": 3},
	# A Centaur pack (see CENTAUR_WAVE_START/CENTAUR_PACK_SIZE) is a mix of
	# these two, rolled independently per spawn (Centaur.gd:has_bow) -- the
	# Lancer is a plain, harder-hitting melee unit (see get_contact_damage);
	# the Archer inherits the original Archer's straight-line kiting
	# identity, at a shorter range than the Apprentice Mage now has.
	"Centaur Lancer": {"move_range": 2},
	"Centaur Archer": {"move_range": 2, "attack_range": CENTAUR_ARCHER_ATTACK_RANGE, "kites": true, "strafes": true},
	# Never attacks (its 0 damage is baked into FaeHut.gd's own
	# CONTACT_DAMAGE, scaled the same as anything else -- 0 * anything is
	# still 0) -- its only battle behavior is spawns_fae, below.
	"Fae Hut": {"move_range": 1, "spawns_fae": true},
	# Small and fast, but barely a threat alone -- see FAE_HUT_SPAWN_INTERVAL.
	"Fae": {},
	# HP/damage scaling itself lives in _setup_battle_grid (HP, one-time) and
	# the normal-attack branch of _process_enemy_turn (damage, live) --
	# big_squad so a Gnome-initiated fight can actually seat a pack of up to
	# GNOME_PACK_SIZE_MAX (5) once _squad_size_bonus allows it.
	"Gnome": {"big_squad": true},
	"Druid": {"heals_allies": true, "buffs_allies": true},
	# Beach's miniboss -- a short-range psychic reach (ignore_line, like the
	# Apprentice Mage but shorter) instead of a straight-line melee attack,
	# plus the same telegraph/enrage shape every Boss-tier unit uses.
	"Aboleth": {"windup": true, "attack_range": 2, "ignore_line": true, "armored": true, "knockback_resist": ORC_KNOCKBACK_RESIST_CHANCE, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Beach's world-ending boss -- a sweeping wave (sweeps, like the Owlbear)
	# that can catch the player and an adjacent ally at once, and resists
	# being knocked around even harder than the Owlbear does.
	"Water Elemental": {"windup": true, "sweeps": true, "armored": true, "knockback_resist": 0.9, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Swamp's miniboss -- fast and squishy, frequent quick jabs (many small
	# reptiles biting) instead of one heavy telegraphed hit.
	"Lizard Soldier Swarm": {"windup": true, "move_range": 2, "quick_jab_chance": 0.5, "knockback_resist": ORC_KNOCKBACK_RESIST_CHANCE, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Swamp's world-ending boss -- a breath-weapon sweep.
	"Black Dragonlet": {"windup": true, "sweeps": true, "armored": true, "knockback_resist": 0.7, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_bleed": true},
	# Forest's miniboss -- rooted and tanky, resists being shoved.
	"Treant": {"windup": true, "armored": true, "knockback_resist": 0.85, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Forest's world-ending boss -- Treant aged up, a wide branch sweep.
	"Elder Oak": {"windup": true, "sweeps": true, "armored": true, "knockback_resist": 0.9, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Desert's miniboss -- erratic: hard to pin down and bites more than once.
	"Gibbering Mouther": {"windup": true, "ignore_line": true, "dodge_chance": 0.25, "quick_jab_chance": 0.4, "move_range": 2, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_blind": true, "inflicts_fear": true},
	# Desert's world-ending boss -- an immovable construct.
	"Iron Golem": {"windup": true, "armored": true, "knockback_resist": 1.0, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_concussion": true},
	# Caves' miniboss -- a literal 2x2 giant footprint (like the Owlbear),
	# the first of these new bosses to take up more than one tile.
	"Stone Giant": {"windup": true, "size": 2, "armored": true, "knockback_resist": 0.8, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_concussion": true},
	# Caves' world-ending boss -- a wide-reaching multi-eye sweep (bigger
	# attack_range than a melee-adjacent dragon's sweep).
	"Beholder": {"windup": true, "sweeps": true, "attack_range": 2, "armored": true, "knockback_resist": 0.5, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_blind": true},
	# Tundra's miniboss -- an armored brawler with frequent quick jabs.
	"Frost Giant": {"windup": true, "armored": true, "knockback_resist": 0.75, "quick_jab_chance": 0.3, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_concussion": true},
	# Tundra's world-ending boss -- an icy breath sweep.
	"White Dragon": {"windup": true, "sweeps": true, "armored": true, "knockback_resist": 0.7, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Mountains' miniboss -- fast and evasive, frequent quick talon strikes.
	"Roc": {"windup": true, "move_range": 3, "dodge_chance": 0.2, "quick_jab_chance": 0.3, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Mountains' world-ending boss -- a wide-reaching lightning-breath sweep.
	"Blue Dragon": {"windup": true, "sweeps": true, "attack_range": 2, "armored": true, "knockback_resist": 0.75, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Volcano's miniboss -- a molten cousin of the Iron Golem, lumbering
	# rather than fully immovable.
	"Lava Golem": {"windup": true, "armored": true, "knockback_resist": 0.65, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# Volcano's world-ending boss -- the tankiest dragon yet ("Wyrm" reads
	# ancient/elder), with the same wide breath reach as Beholder/Blue Dragon.
	"Red Wyrm": {"windup": true, "sweeps": true, "attack_range": 2, "armored": true, "knockback_resist": 0.8, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_bleed": true},
	# Voidlands' miniboss -- fast, evasive, and genuinely ranged (void bolts
	# that ignore obstacles), unlike the melee-only Roc it echoes.
	"Voidwing": {"windup": true, "move_range": 3, "dodge_chance": 0.3, "ignore_line": true, "attack_range": 2, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true, "inflicts_bleed": true},
	# Voidlands' world-ending boss -- the last "normal" world boss before
	# Nothingness, and the one that gets rematched there (see
	# scripts/SupremeWarlock.gd's power_tier). A wide multi-target spell
	# that ignores obstacles entirely, unarmored (a glass-cannon caster,
	# not a brute).
	"Supreme Warlock": {"windup": true, "sweeps": true, "ignore_line": true, "attack_range": 2, "knockback_resist": 0.4, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	# --- Nothingness boss rush (World Progression feature) -- the hardest
	# tier of enemy in the game, deliberately combining more traits at once
	# than any single world's miniboss/boss. See _spawn_nothingness_fight
	# and NOTHINGNESS_BOSSES/NOTHINGNESS_POWER_TIERS below. ---
	"Demogorgon": {"windup": true, "sweeps": true, "armored": true, "knockback_resist": 0.85, "quick_jab_chance": 0.35, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	"Tiamat": {"windup": true, "sweeps": true, "attack_range": 2, "ignore_line": true, "armored": true, "knockback_resist": 0.8, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	"Count Strahd": {"windup": true, "move_range": 2, "dodge_chance": 0.35, "armored": true, "knockback_resist": 0.7, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	"Duke Zalto": {"windup": true, "size": 2, "armored": true, "knockback_resist": 1.0, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
	"Acererak": {"windup": true, "sweeps": true, "attack_range": 2, "ignore_line": true, "armored": true, "knockback_resist": 0.6, "quick_jab_chance": 0.3, "move_range": 1, "enrage_threshold": BOSS_ENRAGE_HP_THRESHOLD, "enrage_mult": BOSS_ENRAGE_DAMAGE_MULT, "is_boss_tier": true},
}

# The Nothingness (world index 10, WORLDS.size()-1) is a fixed 6-fight
# sequential gauntlet, not the normal wave-climbing waterfall -- see
# _spawn_wave's top-of-function branch and _spawn_nothingness_fight below.
# Power climbs fight-to-fight via each script's power_tier field (same
# generic hook _setup_battle_grid already reads for Supreme Warlock's
# rematch, see e.get("power_tier") there) -- fight 6 re-fights Voidlands'
# own Supreme Warlock at its highest tier, closing the loop.
const NOTHINGNESS_BOSSES := [DemogorgonScript, TiamatScript, CountStrahdScript, DukeZaltoScript, AcererakScript, SupremeWarlockScript]
const NOTHINGNESS_POWER_TIERS := [1.0, 1.15, 1.3, 1.45, 1.6, 2.5]

# Stamina exists only for the tile battle. The free regular attack and
# defending both build it back up, so a fight has a rhythm: throw plain
# attacks (or brace) to bank stamina, then cash it in on a heavy hit or one
# of the current weapon's 3 specials when you've got enough saved up.
# Defending grants noticeably more than attacking, since giving up your
# turn's offense is the deliberate "bank a lot of stamina fast" choice.
const STAMINA_REGEN_ON_ATTACK := 10
const STAMINA_REGEN_ON_DEFEND := 25

# Enemy HP/damage in battle scale up with the player's level, so growing
# stronger doesn't make the same enemies trivial forever.
const ENEMY_LEVEL_SCALING := 0.05

# Any non-Boss spawn has a flat chance to roll Elite -- a tougher fight that
# guarantees a Runic Shard drop (the currency the shop's Enchant tab spends).
# Applied at spawn time (_spawn_enemies) and read again in _setup_battle_grid
# when battle stats are computed.
const ELITE_CHANCE := 0.15
const ELITE_HP_MULT := 1.6
const ELITE_DAMAGE_MULT := 1.3
const ELITE_TINT := Color(1.3, 1.0, 1.5)

# A rare, independent roll from ELITE_CHANCE, only checked for Wolf spawns
# (see _spawn_enemies) -- a Traitor Wolf has a further chance to defect and
# join the player's party on death (_on_wolf_died) instead of just dropping
# loot. Combat stats are identical to a plain Wolf; this only changes name/
# tint/recruitment eligibility.
const TRAITOR_WOLF_CHANCE := 0.15
const TRAITOR_WOLF_RECRUIT_CHANCE := 0.25
const TRAITOR_WOLF_TINT := Color(1.4, 0.6, 0.6)
# A recruited (or Beastmaster-guaranteed) Traitor Wolf's loyalty doesn't
# last forever -- see wolf_waves_remaining below, decremented once per wave
# cleared in _on_shop_continue_pressed. Pack Bond (deep Warrior node) adds
# player.meta_wolf_bonus_waves on top.
const WOLF_BASE_STAY_WAVES := 5

# Random events: rolled once per wave transition (_on_shop_continue_pressed),
# against whatever's currently eligible (_available_event_ids).
const EVENT_CHANCE := 0.35
const SWARM_BONUS_GOBLINS := 4
const SHRINE_EFFECT_WAVES := 3
const MERCHANT_EVENT_DISCOUNT := 0.6

# The player can reposition a little every turn no matter which action they
# take -- 2 tiles at baseline agility, +1 more tile per this much agility
# gained above the baseline. At +5 agility per level-up pick, that's an
# extra tile roughly every 4 levels invested, instead of every 40.
const PLAYER_BASE_MOVE_RANGE := 2
const AGILITY_PER_EXTRA_MOVE := 20

# The 10-world campaign (index 0-9) plus the Nothingness boss rush (index
# 10). "terrain" is the RESERVED_TERRAIN_TYPES subset rolled into that
# world's battles alongside the always-on rock/water/ledge/cliff set (empty
# for Plains and Nothingness, which stick to the base 4). Plains reuses the
# existing Boss/Owlbear pair -- see _spawn_boss_wave -- so it carries no
# miniboss_script/boss_script of its own; every other world (and
# Nothingness's own sequential rush, see _spawn_nothingness_fight) supplies
# both.
## miniboss_script/boss_script placeholders: every world reuses Boss/Owlbear
# until its own dedicated pair is authored (see the World Progression plan's
# Phase 3+) -- _spawn_boss_wave reads these generically, so a world "gains"
# its real bosses just by swapping these two fields in, no other code
# changes. Nothingness doesn't use this table at all (see
# _spawn_nothingness_fight once that lands) -- its entry is a placeholder.
const WORLDS := [
	{"name": "Plains", "terrain": [], "ground_tint": Color(1, 1, 1), "battle_bg": Color(0.05, 0.05, 0.05), "miniboss_script": BossScript, "boss_script": OwlbearScript},
	{"name": "Beach", "terrain": [], "ground_tint": Color(1.15, 1.1, 0.85), "battle_bg": Color(0.08, 0.08, 0.1), "miniboss_script": AbolethScript, "boss_script": WaterElementalScript},
	{"name": "Swamp", "terrain": ["poison_bog"], "ground_tint": Color(0.75, 0.85, 0.65), "battle_bg": Color(0.04, 0.06, 0.03), "miniboss_script": LizardSoldierSwarmScript, "boss_script": BlackDragonletScript},
	{"name": "Forest", "terrain": ["thicket"], "ground_tint": Color(0.7, 0.95, 0.7), "battle_bg": Color(0.03, 0.06, 0.03), "miniboss_script": TreantScript, "boss_script": ElderOakScript},
	{"name": "Desert", "terrain": ["quicksand"], "ground_tint": Color(1.3, 1.05, 0.7), "battle_bg": Color(0.1, 0.07, 0.03), "miniboss_script": GibberingMoutherScript, "boss_script": IronGolemScript},
	{"name": "Caves", "terrain": ["crumbling"], "ground_tint": Color(0.55, 0.55, 0.6), "battle_bg": Color(0.02, 0.02, 0.03), "miniboss_script": StoneGiantScript, "boss_script": BeholderScript},
	{"name": "Tundra", "terrain": ["ice"], "ground_tint": Color(0.85, 0.95, 1.2), "battle_bg": Color(0.06, 0.07, 0.09), "miniboss_script": FrostGiantScript, "boss_script": WhiteDragonScript},
	{"name": "Mountains", "terrain": ["rubble"], "ground_tint": Color(0.8, 0.78, 0.75), "battle_bg": Color(0.05, 0.05, 0.06), "miniboss_script": RocScript, "boss_script": BlueDragonScript},
	{"name": "Volcano", "terrain": ["embers"], "ground_tint": Color(1.2, 0.6, 0.5), "battle_bg": Color(0.1, 0.02, 0.01), "miniboss_script": LavaGolemScript, "boss_script": RedWyrmScript},
	{"name": "Voidlands", "terrain": ["caltrops", "spring"], "ground_tint": Color(0.6, 0.55, 0.85), "battle_bg": Color(0.02, 0.01, 0.05), "miniboss_script": VoidwingScript, "boss_script": SupremeWarlockScript},
	{"name": "Nothingness", "terrain": [], "ground_tint": Color(0.25, 0.25, 0.3), "battle_bg": Color(0.0, 0.0, 0.0), "miniboss_script": BossScript, "boss_script": OwlbearScript},
]

const SHOP_OPEN_DELAY := 2.0

# Only some of the 8 upgradeable weapon types show up per shop visit --
# you're not guaranteed to see all of spear/greatsword/hammer/battle
# axe/dagger/bow/knuckle gloves/hand picks every time, on top of the existing
# tier+material roll. Bumped alongside the weapon roster so a typical visit
# still shows about half the roster instead of a third of it.
const SHOP_WEAPON_SLOTS := 4

const REROLL_BASE_COST := 10
const REROLL_COST_INCREMENT := 10
# Flat cost to lock a rolled (non-Club) weapon offer so it survives a
# reroll -- see _roll_shop_offering's locked_weapons handling.
const SHOP_LOCK_COST := 5

var hud: HUDScript
var ground: TextureRect
var player: PlayerScript
var enemies_alive := 0
var game_over := false
var choosing_stat := false
var menu_open := false
var settings_open := false
var shop_open := false
var wave_clearing := false
var shop_open_delay_timer := 0.0
var shop_reroll_count := 0
var current_shop_offering := []
var wave := 1
# Which entry of WORLDS the current wave falls in -- see _world_index_for_wave.
# Recomputed every wave transition (_on_shop_continue_pressed) and once at
# boot (_ready), never written anywhere else.
var current_world_index := 0
# Set once the Nothingness boss rush's 6th fight has been cleared (win or
# repeat) -- from then on current_world_index is pinned to Voidlands (see
# _complete_nothingness_rush) and never recomputed from wave again, for the
# rest of THIS run.
var nothingness_rush_complete := false
# Run-end stats recap: additive counters only, incremented at their natural
# existing call sites (_on_enemy_died, _apply_single_hit, _enemy_apply_damage)
# and read once at run end (_on_player_died / _complete_nothingness_rush) to
# build the HUD recap and feed SaveData.gd's lifetime aggregates. Never reset
# mid-run -- a fresh Main.tscn instance (one per run) is the only "reset"
# these need.
var run_kills_by_name := {}
var run_damage_dealt := 0
var run_damage_taken := 0
var run_bosses_defeated := 0
# Random events: event_choosing pauses/shows HUD's event_panel the same way
# choosing_stat does for the level-up panel. pending_event_weapon is the
# Traveling Merchant's rolled offer, snapshotted once when the event starts
# so its description and its Buy handler agree on exactly what was offered.
# event_extra_goblins/event_force_elite are one-shot flags consumed (and
# reset) by the very next _spawn_wave() call.
var event_choosing := false
var active_event_id := ""
var pending_event_weapon: Dictionary = {}
var shrine_effect_waves_remaining := 0
# Traitor Wolf's loyalty timer -- see WOLF_BASE_STAY_WAVES. 0 whenever
# player.party_wolf is empty; set the moment a wolf joins (recruited via
# _on_wolf_died, or guaranteed at run start by Beastmaster), decremented
# once per wave cleared in _on_shop_continue_pressed.
var wolf_waves_remaining := 0
var event_extra_goblins := 0
var event_force_elite := false
var prev_num_key := {1: false, 2: false, 3: false, 4: false, 5: false, 6: false, 7: false, 8: false}
var prev_shop_num_key := {1: false, 2: false, 3: false, 4: false, 5: false, 6: false, 7: false, 8: false, 9: false}
var prev_enter_key := false
var prev_reroll_key := false
var prev_c_key := false

var in_battle := false
# First-ever-battle interactive tutorial. Gated device-wide via
# SaveData.gd:is_tutorial_completed_ever (not per-save-slot). tutorial_step:
# 0=Move, 1=Fight, 2=Defend. Set once in trigger_battle, left untouched by
# _setup_battle_grid's per-battle reset block.
var tutorial_active := false
var tutorial_step := 0
var battle_terrain := {}
var battle_units := []
# Battle-time representation of the player's recruited party (party_members +
# party_wolf), parallel to battle_units for the enemy side. Rebuilt fresh
# every _setup_battle_grid call -- see the ALLY_* consts above for why.
var battle_allies := []
var battle_player_tile := Vector2i.ZERO
var battle_player_moves_left := 0
var battle_target_index := 0
# Hand Picks' Mine action: the player's explicitly clicked rock/rubble tile,
# a sentinel (-1,-1) meaning none -- see _effective_rock_target.
var battle_rock_target := Vector2i(-1, -1)
var battle_player_defending := false
# Taunt: identical single-enemy-turn shape to battle_player_defending above
# (same reset points, same _apply_incoming_reductions damage-reduction gate)
# -- forces every enemy onto the player this coming enemy turn instead of
# picking freely, protecting allies. See _process_enemy_turn's target_tile
# line.
var battle_player_taunting := false
# Guardian's Ultimatum (Survivor capstone): turns remaining before the Skill
# button can be used again. Reset at battle start, decremented once per
# player turn regardless of which action ended it.
var battle_skill_cooldown := 0
# Battle Axe's Devastating Slash: the player's own next turn(s) are skipped
# entirely (the menu never opens) -- checked/decremented right where the
# turn cycle would otherwise hand control back to the player.
var battle_player_turns_to_skip := 0
# Poison Bog (reserved terrain): mirrors an enemy's own poison_turns/
# poison_dmg fields, but the player isn't a battle_units dict so these live
# here instead. Ticked at the same hand-back-to-player point Second Breath
# already uses.
var player_poison_turns := 0
var player_poison_dmg := 0
# Burn: no turn counter -- persists until the player steps onto a water tile
# (cleared in _apply_water_push). Ticked alongside poison.
var player_burning := false
# Concussion: mirrors an enemy's own concussed_turns field (see BONK), but
# rolled fresh each turn (PLAYER_CONCUSSION_CHANCE) rather than ticking a
# guaranteed hit like poison/burn.
var player_concussed_turns := 0
# Bleeding: no turn counter, guaranteed-on-hit from an inflicts_bleed enemy,
# lasts the rest of the battle (see BLEED_MOVE_DAMAGE_PCT/BLEED_DODGE_DAMAGE_PCT).
var player_bleeding := false
# Blindness: turn-counted like Concussion/Frozen -- see BLINDNESS_TURNS.
var player_blind_turns := 0
# Fear: which enemy (by battle_units index, -1 = none) is currently forcing
# the player's whole turn to Attack-that-enemy-only. Re-derived at the top of
# every player turn from live enemy positions/ranges rather than stored
# across turns, so a feared enemy dying or leaving range frees the player up
# immediately rather than a turn late.
var battle_feared_by_index := -1
# Resolving a forced Fear turn calls straight through _battle_player_fight/
# _end_player_turn, which -- same as battle_player_turns_to_skip already does
# -- synchronously cascades ally-turn (skipped if empty) into ANOTHER
# _process_enemy_turn call on the same stack, no return to the event loop in
# between. turns_to_skip is safe because it's a decrementing counter; Fear
# re-derives the same condition fresh every pass, so with no allies and a
# feared enemy that never becomes reachable (e.g. a kiting ranged unit the
# player can't melee back), that cascade never terminates on its own --
# unbounded recursion, a real hang/crash, not just a test artifact. This
# caps how many consecutive forced rounds can cascade in one synchronous
# burst before falling through to a real menu open, which also resets it to
# 0 -- purely a recursion-depth safety valve, not a gameplay rule.
var battle_fear_cascade_depth := 0
const FEAR_CASCADE_LIMIT := 8
# Momentum: how many enemies the player has defeated THIS battle, reset in
# _setup_battle_grid -- read in _apply_single_hit as a damage-mult stack.
var battle_momentum_stacks := 0
var battle_turn := "player"
# "main" shows Move/Fight/Item/Defend/Flee; "fight" shows the attack submenu
# (Attack/Heavy/3 Specials/Back); "move" shows Confirm/Cancel while arrows
# freely reposition the player.
var battle_menu_state := "main"
# Snapshot taken when entering "move" mode, restored on Cancel -- lets a
# whole pending move (including any cliff-fall damage) be undone before
# it's locked in. battle_move_trail is the Pokemon-Conquest-style arrow
# path shown for the current move session; {tile: Vector2i, dir: Vector2i}.
var battle_move_undo_tile := Vector2i.ZERO
var battle_move_undo_moves_left := 0
var battle_move_undo_health := 0
var battle_move_trail := []
var prev_battle_keys := {}
# Phantom Guard's "evasive": while true, the enemy turn that triggered a
# dodge is paused (see _enemy_apply_damage/_prompt_evasion_reposition) and
# directional input repositions the player instead of doing nothing --
# handled at the very top of _handle_battle, ahead of the normal
# battle_turn == "player" gate, since this happens mid-"enemy" turn.
var battle_awaiting_evasion := false
var evasion_steps_left := 0

var sfx_streams := {}
var sfx_players := []
var sfx_next_player := 0
var settings: Node

var camera: Camera2D
# Screen shake: strength/duration set once at trigger time, timer decays
# every frame back to 0 -- a smaller shake never cuts a bigger one already
# in progress short. Camera (overworld) and the battle panel (tile battle)
# each get their own independent state since both can be shaking at once
# (a battle can open mid-shake from the contact hit that triggered it).
var camera_shake_timer := 0.0
var camera_shake_duration := 0.01
var camera_shake_strength := 0.0
var battle_shake_timer := 0.0
var battle_shake_duration := 0.01
var battle_shake_strength := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	# The Settings autoload isn't resolvable as a bare global identifier at
	# GDScript compile time for a script loaded this early in a bare
	# SceneTree's first frame (confirmed empirically) -- a runtime node
	# lookup, cached once _ready() actually runs, sidesteps that entirely.
	settings = get_node("/root/Settings")
	_build_world()
	_spawn_player()
	_spawn_wave()
	_build_hud()
	ground.texture = hud.grass_animated_texture
	_apply_world_visuals()
	_build_camera()
	_build_sfx()

# Every clip is synthesized once at startup (see Sfx.gd) and reused for
# every playback -- a small round-robin player pool so overlapping sounds
# (e.g. cleave_all hitting several enemies in one action) don't cut each
# other off the way a single shared AudioStreamPlayer would.
func _build_sfx() -> void:
	sfx_streams = {
		"hit": SfxScript.make_hit(),
		"death": SfxScript.make_death(),
		"coin": SfxScript.make_coin(),
		"item": SfxScript.make_item(),
		"shard": SfxScript.make_shard(),
		"level_up": SfxScript.make_level_up(),
		"purchase": SfxScript.make_purchase(),
		"error": SfxScript.make_error(),
		"mine": SfxScript.make_mine(),
		"shield_block": SfxScript.make_shield_block(),
		"shield_knockback": SfxScript.make_shield_knockback(),
		"fae_spawn": SfxScript.make_fae_spawn(),
		"heal": SfxScript.make_heal(),
		"buff": SfxScript.make_buff(),
	}
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

func _exit_tree() -> void:
	# AudioStreamPlaybackWAV instances (and the AudioStreamWAV resources
	# they reference) otherwise linger past a still-playing AudioStreamPlayer's
	# node teardown -- harmless at a real process exit, but noisy "leaked
	# instance" warnings in headless test runs. Dropping the stream reference
	# directly is more reliable than stop() alone, whose internal playback
	# cleanup is a deferred audio-thread tick that may never run before a
	# headless SceneTree finishes tearing down.
	for player in sfx_players:
		player.stop()
		player.stream = null
	sfx_streams.clear()

func play_sfx(name: String) -> void:
	if not sfx_streams.has(name):
		return
	var player: AudioStreamPlayer = sfx_players[sfx_next_player]
	sfx_next_player = (sfx_next_player + 1) % sfx_players.size()
	player.stream = sfx_streams[name]
	player.play()

# Same gentle side-to-side sway as the battle grid's grass (see HUD.gd) --
# built separately here since _build_world() runs before _build_hud() and
# has no HUD instance yet to borrow one from.
func _build_world() -> void:
	# A plain static frame for now -- swapped for HUD's shared
	# grass_animated_texture once HUD exists (see _ready()). Godot doesn't
	# animate correctly when two separate AnimatedTexture instances wrap the
	# same underlying frame files, so the overworld ground and the battle
	# grid's default tile share one single instance instead of each building
	# their own (confirmed via a throwaway second wrapper around the water
	# frames reproducing the exact same stuck-on-frame-0 symptom).
	ground = TextureRect.new()
	ground.texture = preload("res://Sprites/GrassTile.png")
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.size = WORLD_SIZE
	ground.position = Vector2.ZERO
	ground.z_index = -10
	add_child(ground)

	var thickness := 32.0
	_add_wall(Vector2(WORLD_SIZE.x / 2, -thickness / 2), Vector2(WORLD_SIZE.x, thickness))
	_add_wall(Vector2(WORLD_SIZE.x / 2, WORLD_SIZE.y + thickness / 2), Vector2(WORLD_SIZE.x, thickness))
	_add_wall(Vector2(-thickness / 2, WORLD_SIZE.y / 2), Vector2(thickness, WORLD_SIZE.y))
	_add_wall(Vector2(WORLD_SIZE.x + thickness / 2, WORLD_SIZE.y / 2), Vector2(thickness, WORLD_SIZE.y))

	_scatter_decorations()

# Trees/bushes/grass tufts, scattered with simple rejection sampling: clear
# of the player's spawn point and spaced apart from each other. Trees block
# movement (a small trunk-sized StaticBody2D, not the whole wide canopy);
# bushes and grass tufts stay pure set dressing.
func _scatter_decorations() -> void:
	var deco_specs := [
		{"texture": preload("res://assets/deco_tree.png"), "count": DECO_TREE_COUNT, "collidable": true},
		{"texture": preload("res://assets/deco_bush.png"), "count": DECO_BUSH_COUNT, "collidable": false},
		{"texture": preload("res://assets/deco_grass_tuft.png"), "count": DECO_GRASS_TUFT_COUNT, "collidable": false},
	]
	var player_spawn := WORLD_SIZE / 2
	var placed_positions := []
	for spec in deco_specs:
		for i in spec.count:
			var pos := Vector2.ZERO
			var found := false
			var attempts := 0
			while attempts < 30 and not found:
				attempts += 1
				pos = Vector2(randf_range(40, WORLD_SIZE.x - 40), randf_range(40, WORLD_SIZE.y - 40))
				if pos.distance_to(player_spawn) < DECO_PLAYER_CLEARANCE:
					continue
				var too_close := false
				for p in placed_positions:
					if pos.distance_to(p) < DECO_MIN_SPACING:
						too_close = true
						break
				found = not too_close
			if not found:
				continue
			placed_positions.append(pos)
			var deco := Sprite2D.new()
			deco.texture = spec.texture
			deco.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			deco.position = pos
			deco.z_index = -5
			add_child(deco)
			if spec.collidable:
				_add_tree_trunk_collision(pos)

# A small collision circle near the trunk (not the wide canopy) -- centered
# a bit below the sprite's own position, since deco_tree.png's trunk sits in
# the lower third of its 24x32 image while Sprite2D positions from center.
func _add_tree_trunk_collision(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos + Vector2(0, 10)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.position = WORLD_SIZE / 2
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.xp_changed.connect(_on_player_xp_changed)
	player.stats_changed.connect(_on_player_stats_changed)
	player.leveled_up.connect(_on_player_leveled_up)
	player.coins_changed.connect(_on_player_coins_changed)
	player.items_changed.connect(_on_player_items_changed)
	add_child(player)
	# Beastmaster guarantees a Traitor Wolf from the start of the run (set
	# inside player._apply_meta_upgrades, already run by the time add_child
	# returns) -- start its loyalty timer the same way a mid-run recruit
	# via _on_wolf_died does.
	if not player.party_wolf.is_empty():
		wolf_waves_remaining = WOLF_BASE_STAY_WAVES + player.meta_wolf_bonus_waves

# Waves 1-100 map onto WORLDS[0..9] ten waves apiece; 101+ is index 10
# (Nothingness), which never advances further -- see _spawn_nothingness_fight
# for how it stops using the normal wave-climbing waterfall entirely.
func _world_index_for_wave(w: int) -> int:
	return mini((w - 1) / WAVES_PER_WORLD, WORLDS.size() - 1)

# Re-tints the overworld ground and refreshes the HUD's world label for
# whatever WORLDS[current_world_index] is right now -- called once at boot
# and again every time a wave transition changes current_world_index.
func _apply_world_visuals() -> void:
	if ground != null:
		ground.modulate = WORLDS[current_world_index].ground_tint
	hud.update_world(_world_label_text())

func _world_label_text() -> String:
	var w: Dictionary = WORLDS[current_world_index]
	if current_world_index == WORLDS.size() - 1:
		return "World: %s" % w.name
	var wave_in_world: int = ((wave - 1) % WAVES_PER_WORLD) + 1
	return "World: %s (%d/%d)" % [w.name, wave_in_world, WAVES_PER_WORLD]

func _spawn_wave() -> void:
	# Nothingness (the last WORLDS entry) is a fixed 6-fight sequential
	# gauntlet, not the normal wave-climbing waterfall below -- checked
	# first and returns early for the 6 rush waves themselves. Once cleared
	# (win or repeat), _complete_nothingness_rush pins current_world_index
	# back to Voidlands and this check no longer matches, so execution falls
	# straight through into the normal waterfall using the (now much
	# higher) wave number -- "endless post-game" needs no code of its own.
	if current_world_index == WORLDS.size() - 1 and not nothingness_rush_complete:
		var fight_index: int = wave - (WAVES_PER_WORLD * (WORLDS.size() - 1) + 1)
		if fight_index < NOTHINGNESS_BOSSES.size():
			_spawn_nothingness_fight(fight_index)
			return
		else:
			_complete_nothingness_rush()
			if game_over:
				# First-ever completion: Victory already shown, run reset
				# like a death -- nothing left to spawn into a paused game.
				return

	# Consumed here regardless of which branch below runs, so a Goblin Swarm/
	# Elite Bounty rolled right before a boss wave doesn't leak into the
	# wave after it -- bosses are always solo anyway (_gather_squad), so
	# there's nothing sensible for either flag to apply to on a boss wave.
	var extra_goblins := event_extra_goblins
	var force_elite := event_force_elite
	event_extra_goblins = 0
	event_force_elite = false

	if wave % BOSS_WAVE_INTERVAL == 0:
		_spawn_boss_wave()
		return

	var goblin_count := ENEMY_COUNT + (wave - 1) + extra_goblins
	var orc_count := ORC_COUNT + (wave - 1) / 2

	_spawn_enemies(EnemyScript, goblin_count, force_elite)
	_spawn_enemies(OrcScript, orc_count)
	if wave >= ARCHER_WAVE_START:
		_spawn_enemies(ArcherScript, 1)
	if wave >= SHAMAN_WAVE_START:
		_spawn_enemies(ShamanScript, 1)
	if wave >= BRUTE_WAVE_START:
		_spawn_enemies(BruteScript, 1)
	if wave >= SHADE_WAVE_START:
		_spawn_enemies(ShadeScript, 1)
	if wave >= WOLF_WAVE_START:
		_spawn_enemies(WolfScript, 1)
	if wave >= CENTAUR_WAVE_START:
		_spawn_enemies(CentaurScript, CENTAUR_PACK_SIZE)
	if wave >= FAE_HUT_WAVE_START:
		_spawn_enemies(FaeHutScript, 1)
	if wave >= GNOME_WAVE_START:
		# A real pack, not a fixed count -- 2 to GNOME_PACK_SIZE_MAX, spawned
		# clustered together (see _spawn_enemies' cluster_radius) so they
		# actually gather into ONE battle instead of scattering across the
		# map and trickling in as separate fights.
		_spawn_enemies(GnomeScript, randi_range(2, GNOME_PACK_SIZE_MAX), false, BATTLE_GATHER_RADIUS * 0.4)
	if wave >= DRUID_WAVE_START:
		_spawn_enemies(DruidScript, 1)

# force_elite guarantees the FIRST spawned enemy is elite (Elite Bounty
# random event) regardless of the normal ELITE_CHANCE roll; every other
# enemy in the batch still rolls normally. cluster_radius > 0 spawns every
# enemy AFTER the first within that radius of it (a real pack), instead of
# each one independently rejection-sampled across the whole map -- see the
# Gnome pack spawn above for why that matters (so _gather_squad's proximity
# check can actually pull the whole pack into one fight).
func _spawn_enemies(enemy_script, count: int, force_elite: bool = false, cluster_radius: float = 0.0) -> void:
	var cluster_origin := Vector2.ZERO
	for i in count:
		var enemy = enemy_script.new()
		if cluster_radius > 0.0 and i > 0:
			enemy.position = cluster_origin + Vector2(randf_range(-cluster_radius, cluster_radius), randf_range(-cluster_radius, cluster_radius))
		else:
			enemy.position = _random_enemy_spawn_position()
			cluster_origin = enemy.position
		if (force_elite and i == 0) or randf() < ELITE_CHANCE:
			enemy.is_elite = true
			# Tinted on the root node, not the child sprite -- every enemy
			# script repaints sprite.modulate every frame for its own damage
			# flash/windup effects, which would otherwise erase this within
			# a single frame. A parent CanvasItem's modulate multiplies
			# through to its children's rendering regardless.
			enemy.modulate = ELITE_TINT
		# Traitor Wolf: a rarer roll on top of (and independent from) Elite,
		# only checked for Wolf spawns. The extra died connection is
		# additional to the normal one below, not instead of it -- only ever
		# wired up here, when is_traitor is already known true, so
		# _on_wolf_died firing at all is proof enough of which enemy it was;
		# no need to identify the instance inside the handler itself.
		if enemy_script == WolfScript and randf() < TRAITOR_WOLF_CHANCE:
			enemy.is_traitor = true
			enemy.modulate = TRAITOR_WOLF_TINT
			enemy.died.connect(_on_wolf_died)
		enemy.died.connect(_on_enemy_died.bind(enemy.get_display_name()))
		add_child(enemy)
		enemies_alive += 1

# Same rejection-sampling shape as _scatter_decorations, just clearing the
# player instead of other decorations -- 30 attempts, then place wherever the
# last roll landed rather than risk a hang on a cramped map.
func _random_enemy_spawn_position() -> Vector2:
	var pos := Vector2.ZERO
	var attempts := 0
	while attempts < 30:
		attempts += 1
		pos = Vector2(randf_range(60, WORLD_SIZE.x - 60), randf_range(60, WORLD_SIZE.y - 60))
		if pos.distance_to(player.global_position) >= ENEMY_SPAWN_CLEARANCE:
			break
	return pos

func _spawn_boss_wave() -> void:
	# Data-driven off WORLDS[current_world_index]: wave 5-of-10 in any world
	# is that world's miniboss, wave 10-of-10 (the world's last wave) is its
	# full boss -- both fields default to Boss/Owlbear (see WORLDS) until a
	# world's own dedicated pair is authored, so this never has a missing
	# script to fall back on.
	var world: Dictionary = WORLDS[current_world_index]
	var wave_in_world: int = ((wave - 1) % WAVES_PER_WORLD) + 1
	var is_miniboss: bool = wave_in_world == WAVES_PER_WORLD / 2
	var boss_script = world.miniboss_script if is_miniboss else world.boss_script
	var boss = boss_script.new()
	boss.position = _random_enemy_spawn_position()
	boss.died.connect(_on_enemy_died.bind(boss.get_display_name()))
	add_child(boss)
	enemies_alive += 1
	hud.show_message("%s approaches..." % boss.get_display_name())

# fight_index is 0-based (wave 101 -> 0, ... wave 106 -> 5). power_tier is
# set generically the same way SupremeWarlock's own rematch works --
# `.get()` returns null (not an error) for the 4 scripts that don't define
# the property, so this never assumes every NOTHINGNESS_BOSSES entry does.
func _spawn_nothingness_fight(fight_index: int) -> void:
	var boss_script = NOTHINGNESS_BOSSES[fight_index]
	var boss = boss_script.new()
	if boss.get("power_tier") != null:
		boss.power_tier = NOTHINGNESS_POWER_TIERS[fight_index]
	boss.position = _random_enemy_spawn_position()
	boss.died.connect(_on_enemy_died.bind(boss.get_display_name()))
	add_child(boss)
	enemies_alive += 1
	hud.show_message("%s approaches... (%d/%d)" % [boss.get_display_name(), fight_index + 1, NOTHINGNESS_BOSSES.size()])

# The rush's 6th fight has just been cleared. First time ever (checked
# against the lifetime file, not this slot -- see SaveData.gd), this is the
# game's only win condition: banks essence same as a death would, but framed
# as a win, then resets the run the same permadeath way. Every later
# clearing (this slot or any other, after the lifetime flag is set) instead
# drops straight into an endless post-game reusing Voidlands' own content --
# see _spawn_wave's comment for how that actually works.
func _complete_nothingness_rush() -> void:
	# Captured before current_world_index is pinned to Voidlands below, so a
	# first-time Victory's recap correctly says "Nothingness" (world index
	# 10), not the endless post-game's Voidlands.
	var stats: Dictionary = _run_stats_summary()
	nothingness_rush_complete = true
	current_world_index = 9
	_apply_world_visuals()
	if not SaveDataScript.is_game_completed_ever():
		SaveDataScript.mark_game_completed()
		var essence_earned: int = SaveDataScript.record_run_result(wave - 1)
		var total_essence: int = SaveDataScript.load_data().get("essence", 0)
		SaveDataScript.record_lifetime_run_stats(stats.kills_by_name, stats.world_reached, 10, stats.bosses_defeated)
		SaveDataScript.delete_slot(SaveDataScript.active_slot)
		game_over = true
		get_tree().paused = true
		hud.show_victory(essence_earned, total_essence, stats)
	else:
		hud.show_message("The Nothingness falls silent once more... you press on.")

func _build_hud() -> void:
	hud = HUDScript.new()
	add_child(hud)
	hud.battle_main_action.connect(_on_battle_main_action)
	hud.battle_fight_action.connect(_on_battle_fight_action)
	hud.battle_move_action.connect(_on_battle_move_action)
	hud.battle_arrow_action.connect(_on_battle_arrow_action)
	hud.battle_tactics_action.connect(_on_battle_tactics_action)
	hud.enemy_hovered.connect(_on_enemy_hovered)
	hud.enemy_unhovered.connect(_on_enemy_unhovered)
	hud.battle_evasion_confirm_pressed.connect(func(): evasion_confirmed.emit())
	hud.rock_target_selected.connect(_on_rock_target_selected)
	hud.levelup_choice_pressed.connect(_on_levelup_choice_pressed)
	hud.event_choice_pressed.connect(_on_event_choice_pressed)
	hud.menu_resume_pressed.connect(_close_pause_menu)
	hud.settings_pressed.connect(_on_settings_pressed)
	hud.settings_back_pressed.connect(_on_settings_back_pressed)
	hud.shop_buy_pressed.connect(_on_shop_buy_pressed)
	hud.shop_lock_pressed.connect(_on_shop_lock_pressed)
	hud.shop_reroll_pressed.connect(_on_shop_reroll_pressed)
	hud.shop_continue_pressed.connect(_on_shop_continue_pressed)
	hud.enchant_apply_pressed.connect(_on_enchant_apply_pressed)
	hud.arrow_buy_pressed.connect(_on_arrow_buy_pressed)
	hud.arrow_sell_pressed.connect(_on_arrow_sell_pressed)
	hud.game_over_return_pressed.connect(_on_game_over_return_pressed)
	hud.enemy_target_selected.connect(_on_enemy_target_selected)
	hud.tutorial_skip_pressed.connect(_on_tutorial_skip_pressed)
	hud.update_health(player.health, player.max_health)
	hud.update_coins(player.coins)
	hud.update_items(player.healing_items)
	hud.update_enemies(enemies_alive)
	hud.update_wave(wave)
	hud.update_level(player.level)
	hud.update_xp(player.xp, player.xp_to_next)
	hud.update_stats(player.stat_intimidation, player.stat_strength, player.stat_vigor, player.stat_agility, player.stat_might)
	hud.update_quiver(_player_has_bow(), player.owned_arrows)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	camera.make_current()

# strength in pixels, duration in seconds -- see the shake state vars for why
# a weaker shake never interrupts a stronger one already playing.
func _shake_camera(strength: float, duration: float) -> void:
	if not settings.screen_shake_enabled:
		return
	if camera_shake_timer > 0.0 and strength < camera_shake_strength:
		return
	camera_shake_strength = strength
	camera_shake_duration = duration
	camera_shake_timer = duration

func _shake_battle(strength: float, duration: float) -> void:
	if not settings.screen_shake_enabled:
		return
	if battle_shake_timer > 0.0 and strength < battle_shake_strength:
		return
	battle_shake_strength = strength
	battle_shake_duration = duration
	battle_shake_timer = duration

# Public wrapper so Player.gd/enemy scripts can shake the overworld camera
# via the same has_method() duck-typing pattern used everywhere else here.
func notify_camera_shake(strength: float, duration: float) -> void:
	_shake_camera(strength, duration)

func _update_shake(delta: float) -> void:
	if camera_shake_timer > 0.0:
		camera_shake_timer = max(0.0, camera_shake_timer - delta)
		var fade: float = camera_shake_timer / camera_shake_duration
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * camera_shake_strength * fade
	elif camera != null and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	if battle_shake_timer > 0.0:
		battle_shake_timer = max(0.0, battle_shake_timer - delta)
		var fade: float = battle_shake_timer / battle_shake_duration
		hud.battle_panel.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * battle_shake_strength * fade
	elif hud != null and hud.battle_panel.position != Vector2.ZERO:
		hud.battle_panel.position = Vector2.ZERO

const DEATH_BURST_PARTICLE_COUNT := 6

# World-space floating damage number for the real-time overworld combat --
# tweens upward and fades out, then frees itself. `pos` is a
# global_position (Node2D world coords). Public (no underscore) so
# Player.gd and every enemy script can call it via the same has_method()
# duck-typing pattern trigger_battle already uses on their `get_parent()`,
# without needing a typed Main reference.
func spawn_damage_number_world(pos: Vector2, amount: int) -> void:
	if not settings.damage_numbers_enabled:
		return
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.global_position = pos + Vector2(-8, -20)
	label.z_index = 10
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -24), 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

# Same idea, but for the battle grid (a HUD CanvasLayer overlay, screen-space
# pixel coords, not a Node2D) -- called directly from Main.gd's own battle
# resolution code, not via has_method(), so it stays private.
func _spawn_battle_damage_number(tile: Vector2i, amount: int, size: int = 1) -> void:
	if not settings.damage_numbers_enabled:
		return
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	var tile_origin: Vector2 = hud.battle_grid_origin + Vector2(tile.x, tile.y) * hud.battle_tile_size
	label.position = tile_origin + Vector2(hud.battle_tile_size * size / 2.0 - 8, 0)
	hud.battle_panel.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -20), 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

# World-space death burst (a handful of small flung, fading ColorRects --
# matches this project's flat-pixel-art look better than a texture-based
# particle system). Public for the same has_method() reason as
# spawn_damage_number_world above.
func spawn_death_burst(pos: Vector2) -> void:
	for i in DEATH_BURST_PARTICLE_COUNT:
		var particle := ColorRect.new()
		particle.color = Color(0.9, 0.2, 0.15)
		particle.size = Vector2(4, 4)
		particle.global_position = pos - particle.size / 2.0
		add_child(particle)
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var dist := randf_range(14.0, 26.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", particle.global_position + dir * dist, 0.35)
		tween.tween_property(particle, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(particle.queue_free)

func _spawn_battle_death_burst(tile: Vector2i, size: int = 1) -> void:
	var tile_center: Vector2 = hud.battle_grid_origin + Vector2(tile.x, tile.y) * hud.battle_tile_size + Vector2(hud.battle_tile_size * size / 2.0, hud.battle_tile_size * size / 2.0)
	for i in DEATH_BURST_PARTICLE_COUNT:
		var particle := ColorRect.new()
		particle.color = Color(0.9, 0.2, 0.15)
		particle.size = Vector2(4, 4)
		particle.position = tile_center - particle.size / 2.0
		hud.battle_panel.add_child(particle)
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var dist := randf_range(14.0, 26.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + dir * dist, 0.35)
		tween.tween_property(particle, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(particle.queue_free)

# A brief red overlay flashed over a hit tile -- a transient overlay rect
# rather than tweening the pooled unit icon's own modulate directly, since
# that pool gets its modulate reassigned every _refresh_battle_display()
# call (the warm target-highlight), which would otherwise fight a tween
# for the same property and cut the flash short.
func _flash_battle_tile(tile: Vector2i, size: int = 1) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(1.0, 0.15, 0.1, 0.55)
	var span: float = hud.battle_tile_size * size
	overlay.position = hud.battle_grid_origin + Vector2(tile.x, tile.y) * hud.battle_tile_size
	overlay.size = Vector2(span, span)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.battle_panel.add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tween.tween_callback(overlay.queue_free)

const ATTACK_LUNGE_PLAYER_COLOR := Color(1.0, 0.9, 0.3, 0.9)
const ATTACK_LUNGE_ALLY_COLOR := Color(0.4, 0.7, 1.0, 0.9)
const ATTACK_LUNGE_ENEMY_COLOR := Color(0.9, 0.25, 0.2, 0.9)

# The attacking unit's own icon is never animated directly -- like every
# other tile-battle juice helper, this is a transient node instead, because
# _refresh_battle_display() (called every frame during the player's turn,
# see _handle_battle) unconditionally reassigns every pooled icon's
# .position each call, which would fight and cut short any tween on the
# real icon (the same conflict _flash_battle_tile's comment already
# documents for .modulate). Tile-coordinate-driven, not a pool index, so a
# unit dying and shifting battle_units' indices mid-resolution can't
# desync it either.
# `ranged`: a melee attacker jabs partway toward the target and back; a
# ranged one (only the Apprentice Mage's attack_range > 1 today) travels
# the full distance once and fades on arrival -- an actual visible "shot,"
# which ranged attacks have never had.
func _spawn_battle_attack_lunge(from_tile: Vector2i, to_tile: Vector2i, color: Color, ranged: bool) -> void:
	var from_px: Vector2 = hud.battle_grid_origin + (Vector2(from_tile) + Vector2(0.5, 0.5)) * hud.battle_tile_size
	var to_px: Vector2 = hud.battle_grid_origin + (Vector2(to_tile) + Vector2(0.5, 0.5)) * hud.battle_tile_size
	var bolt := ColorRect.new()
	var span: float = hud.battle_tile_size * 0.3
	bolt.size = Vector2(span, span)
	bolt.color = color
	bolt.position = from_px - bolt.size / 2.0
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.battle_panel.add_child(bolt)
	var tween := create_tween()
	if ranged:
		tween.set_parallel(true)
		tween.tween_property(bolt, "position", to_px - bolt.size / 2.0, 0.18)
		tween.tween_property(bolt, "modulate:a", 0.0, 0.18)
		tween.chain().tween_callback(bolt.queue_free)
	else:
		var peak: Vector2 = from_px.lerp(to_px, 0.4)
		tween.tween_property(bolt, "position", peak - bolt.size / 2.0, 0.1)
		tween.chain().set_parallel(true)
		tween.tween_property(bolt, "position", from_px - bolt.size / 2.0, 0.1)
		tween.tween_property(bolt, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(bolt.queue_free)

func _on_player_health_changed(current: int, max_health: int) -> void:
	hud.update_health(current, max_health)

func _on_player_items_changed(amount: int) -> void:
	hud.update_items(amount)

# Shared by both run-end paths (_on_player_died, _complete_nothingness_rush)
# -- everything the HUD recap and SaveData.gd's lifetime aggregates need,
# read once at the moment a run actually ends.
func _run_stats_summary() -> Dictionary:
	return {
		"waves_cleared": wave - 1,
		"world_reached": WORLDS[current_world_index].name,
		"bosses_defeated": run_bosses_defeated,
		"damage_dealt": run_damage_dealt,
		"damage_taken": run_damage_taken,
		"kills_by_name": run_kills_by_name.duplicate(),
	}

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if in_battle:
		in_battle = false
		hud.hide_battle()
	# Bypasses _end_battle() entirely, so the tutorial's own gating/hint
	# state needs its own defensive reset here too.
	tutorial_active = false
	if choosing_stat:
		# A level-up triggered by the same killing blow that finished off
		# the player (both can fire synchronously in the same attack-
		# resolution call stack) shouldn't leave its choice panel dangling
		# behind the game-over screen -- there's no run left to spend it on.
		choosing_stat = false
		hud.hide_levelup_choice()
	get_tree().paused = true
	# Permadeath: waves cleared before dying still compute an Essence total
	# (shown below for the player's benefit -- what this run would have
	# banked), but record_run_result's write is immediately undone by
	# delete_slot -- death wipes the whole slot, not just the run. The
	# title screen offers it as [New Game] again afterward.
	var essence_earned: int = SaveDataScript.record_run_result(wave - 1)
	var total_essence: int = SaveDataScript.load_data().get("essence", 0)
	var stats: Dictionary = _run_stats_summary()
	SaveDataScript.record_lifetime_run_stats(stats.kills_by_name, stats.world_reached, current_world_index, stats.bosses_defeated)
	SaveDataScript.delete_slot(SaveDataScript.active_slot)
	hud.show_game_over(essence_earned, total_essence, stats)

func _on_game_over_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://TitleScreen.tscn")

func _on_enemy_died(xp_reward: int, enemy_name: String = "") -> void:
	play_sfx("death")
	enemies_alive -= 1
	hud.update_enemies(enemies_alive)
	player.gain_xp(xp_reward)
	# Run-end stats recap: enemy_name is only ever empty for older direct/test
	# call sites that don't bind it (see the .died.connect callers above) --
	# a kill from one of those just doesn't show up in the per-name breakdown.
	if enemy_name != "":
		run_kills_by_name[enemy_name] = run_kills_by_name.get(enemy_name, 0) + 1
		if ENEMY_TRAITS.get(enemy_name, {}).get("is_boss_tier", false):
			run_bosses_defeated += 1
	# Momentum: stacks for the rest of THIS battle, reset in
	# _setup_battle_grid -- only tracked at all when the skill is owned, so
	# it can't silently accumulate across a run for players without it.
	if player.meta_momentum_pct_per_kill > 0.0:
		battle_momentum_stacks += 1
	# Rage/Berserk: any kill mid-battle sets/refreshes the timer to the full
	# duration, even if it's already active -- a fresh kill keeps the rage
	# going rather than stacking on top of what's left.
	if in_battle:
		player.berserk_turns_remaining = BERSERK_TURNS
		if enemy_name != "":
			hud.battle_log("Killing the %s sends you into a berserk rage!" % enemy_name)
		else:
			hud.battle_log("You fly into a berserk rage!")
	# Windfall: a flat gold drop, independent of the enemy's own coin/loot
	# (there isn't a per-kill coin drop elsewhere to stack onto).
	if player.meta_windfall_chance > 0.0 and randf() < player.meta_windfall_chance:
		var windfall_amount := randi_range(5, 15)
		player.add_coins(windfall_amount)
		hud.battle_log("Windfall! +%d gold." % windfall_amount)
	# War Profiteer (Warrior + Merchant convergence): flat coins per kill.
	if player.meta_war_profiteer_coins > 0:
		player.add_coins(player.meta_war_profiteer_coins)
	if enemies_alive <= 0 and not game_over and not shop_open and not wave_clearing:
		wave_clearing = true
		shop_open_delay_timer = SHOP_OPEN_DELAY
		hud.show_message("Wave %d cleared!" % wave)

# A Traitor Wolf's death gets this SECOND listener alongside the normal
# _on_enemy_died (which already handled XP/coins/wave-clear above) -- only
# rolls if no wolf is already in the party; a failed roll or an
# already-occupied slot is a silent no-op, matching this session's
# established "graceful miss" pattern for near-miss outcomes elsewhere.
func _on_wolf_died(_xp_reward: int) -> void:
	if not player.party_wolf.is_empty():
		return
	# Beastmaster (repurposed, deep Warrior node) now guarantees a wolf from
	# the start of the run instead -- see Player.gd:_apply_meta_upgrades --
	# so this roll only ever matters for players without it.
	if randf() < TRAITOR_WOLF_RECRUIT_CHANCE:
		player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
		wolf_waves_remaining = WOLF_BASE_STAY_WAVES + player.meta_wolf_bonus_waves
		hud.show_message("The Traitor Wolf defects and joins your pack!")

func _open_shop() -> void:
	wave_clearing = false
	shop_open = true
	shop_reroll_count = 0
	get_tree().paused = true
	# Locks are scoped to a single shop visit -- _roll_shop_offering
	# preserves anything already flagged locked in current_shop_offering
	# (that's how a reroll keeps it), so a fresh visit has to start from an
	# empty offering or last wave's locked item(s) would carry over.
	current_shop_offering = []
	_roll_shop_offering()
	_refresh_shop_display()

func _tagged(item: Dictionary, category: String) -> Dictionary:
	var copy := item.duplicate()
	copy["category"] = category
	return copy

func _roll_shop_offering() -> void:
	# Locked weapon rows (see _on_shop_lock_pressed) survive a reroll --
	# pulled out here and spliced back in below instead of being
	# regenerated. Only non-Club weapon rows are ever lockable (Club/armor/
	# potions are already deterministic every roll -- nothing to protect).
	var locked_weapons: Array = current_shop_offering.filter(func(i): return i.get("locked", false))

	current_shop_offering = [_tagged(WeaponsScript.CLUB, "weapon")]

	var pool: Array = WeaponsScript.UPGRADABLE_TYPES.duplicate()
	pool.shuffle()
	# Investor (repurposed): rolls extra weapon slots into every offering.
	var weapon_slots_to_fill: int = max(0, SHOP_WEAPON_SLOTS + player.meta_investor_bonus_slots - locked_weapons.size())
	for base in pool.slice(0, weapon_slots_to_fill):
		var min_rank: int = max(0, player.get_owned_tier_rank(base.id))
		current_shop_offering.append(_tagged(WeaponsScript.make_variant(base, min_rank, player.luck_bonus), "weapon"))
	current_shop_offering.append_array(locked_weapons)

	# Merchant Prince (Merchant capstone): one extra weapon offer every shop
	# visit, guaranteed Masterwork tier or better. UPGRADABLE_TYPES has more
	# entries than weapon_slots_to_fill uses, so this always picks a base
	# type not already in the offering above.
	if player.has_merchant_prince:
		var remaining: Array = pool.slice(weapon_slots_to_fill)
		var extra_base: Dictionary = remaining[0] if not remaining.is_empty() else pool[0]
		var extra_min_rank: int = max(3, player.get_owned_tier_rank(extra_base.id))
		current_shop_offering.append(_tagged(WeaponsScript.make_variant(extra_base, extra_min_rank, player.luck_bonus), "weapon"))

	var next_armor: Dictionary = ArmorScript.get_next_tier(player.owned_armor)
	if not next_armor.is_empty():
		current_shop_offering.append(_tagged(next_armor, "armor"))

	# Shields aren't a linear tier progression like armor -- all 5 are
	# distinct, so every visit offers whichever ones aren't owned yet, same
	# "always show the full remaining catalog" idea as the potion tiers below.
	for id in ShieldsScript.SHIELD_IDS:
		if not player.owned_shields.has(id):
			current_shop_offering.append(_tagged(ShieldsScript.SHIELDS[id], "shield"))

	for tier in PotionsScript.TIERS:
		current_shop_offering.append(_tagged(tier, "potion"))

func _get_shop_price(item: Dictionary) -> int:
	match item.category:
		"armor":
			return player.get_armor_price(item)
		"shield":
			return player.get_shield_price(item)
		"potion":
			return player.get_potion_price(item)
		_:
			return player.get_weapon_price(item)

func _get_shop_reroll_cost() -> int:
	var base_cost: int = REROLL_BASE_COST + REROLL_COST_INCREMENT * shop_reroll_count
	# Black Market: a straight discount on top of the escalating base cost.
	return int(round(base_cost * (1.0 - player.meta_reroll_discount_pct)))

func _reroll_shop() -> bool:
	var cost := _get_shop_reroll_cost()
	if not player.try_spend_coins(cost):
		return false
	shop_reroll_count += 1
	_roll_shop_offering()
	return true

func _refresh_shop_display() -> void:
	var prices := []
	for item in current_shop_offering:
		prices.append(_get_shop_price(item))
	var arrow_prices := {}
	for kind in player.owned_arrows:
		arrow_prices[kind] = player.get_arrow_price(kind)
	hud.show_shop(player.coins, player.runic_shards, current_shop_offering, prices, player.current_weapon.name, player.owned_weapons, player.equipped_armor.name, player.healing_items, _get_shop_reroll_cost(), _player_has_bow(), player.owned_arrows, arrow_prices, WeaponsScript.ARROW_MAX_HELD + player.meta_arrow_cap_bonus, player.equipped_shield.get("name", "None"), player.owned_shields, player.stat_might)
	_refresh_enchant_display()

func _refresh_enchant_display() -> void:
	var weapon_id: String = player.current_weapon_base.get("id", "")
	var applied_rune_id: String = player.weapon_enchantments.get(weapon_id, "")
	hud.show_enchant_tab(player.coins, player.runic_shards, player.current_weapon_base.name, weapon_id, applied_rune_id, EnchantmentsScript.RUNES)

func _on_enchant_apply_pressed(rune_id: String) -> void:
	var applied: bool = player.try_apply_enchantment(rune_id)
	if applied:
		# weapon_enchantments is keyed by weapon, not rune, so it carries no
		# per-run "first time" signal -- the lifetime seen-flag inside
		# _maybe_announce_unlock is the only source of truth here.
		var rune: Dictionary = EnchantmentsScript.get_rune(rune_id)
		_maybe_announce_unlock("rune:%s" % rune_id, rune.name, rune.description)
	play_sfx("purchase" if applied else "error")
	_refresh_shop_display()

# Protects a rolled (non-Club) weapon offer from being rerolled away, for a
# flat coin cost -- see _roll_shop_offering's locked_weapons handling for
# the other half of this. Already-owned/already-locked/non-weapon/Club rows
# are refused, mirroring the HUD's own is_lockable gate on the button.
func _on_shop_lock_pressed(index: int) -> void:
	if index < 0 or index >= current_shop_offering.size():
		return
	var item: Dictionary = current_shop_offering[index]
	if item.get("locked", false) or item.category != "weapon" or item.id == "club" or player.owned_weapons.has(item.id):
		return
	if not player.try_spend_coins(SHOP_LOCK_COST):
		play_sfx("error")
		return
	current_shop_offering[index] = item.duplicate()
	current_shop_offering[index]["locked"] = true
	play_sfx("purchase")
	_refresh_shop_display()

func _on_arrow_buy_pressed(kind: String) -> void:
	# All 3 kinds are pre-keyed at 0 from run start (Player.gd:owned_arrows),
	# so "first time obtaining" is owned_arrows[kind] == 0, not a .has() check.
	var is_first_arrow: bool = player.owned_arrows.get(kind, 0) == 0
	var bought: bool = player.try_buy_arrow(kind)
	if bought and is_first_arrow:
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		_maybe_announce_unlock("arrow:%s" % kind, info.name, info.description)
	play_sfx("purchase" if bought else "error")
	_refresh_shop_display()

func _on_arrow_sell_pressed(kind: String) -> void:
	var sold: bool = player.try_sell_arrow(kind)
	play_sfx("purchase" if sold else "error")
	_refresh_shop_display()

# Shared "first time you ever obtain X" trigger for weapons/shields/arrows/
# runes (skill tree nodes get their own copy in TitleScreen.gd, which has no
# access to this HUD instance). title/description are always the item's own
# EXISTING name/description text -- no new copy is authored here.
func _maybe_announce_unlock(key: String, title: String, description: String) -> void:
	if SaveDataScript.try_mark_unlock_seen(key):
		hud.show_unlock_popup(title, description)

func _on_player_xp_changed(current: int, needed: int) -> void:
	hud.update_xp(current, needed)

func _on_player_stats_changed(intimidation: int, strength: int, vigor: int, agility: int, might: int) -> void:
	hud.update_stats(intimidation, strength, vigor, agility, might)

func _on_player_coins_changed(amount: int) -> void:
	hud.update_coins(amount)

func _on_player_leveled_up(new_level: int) -> void:
	play_sfx("level_up")
	choosing_stat = true
	get_tree().paused = true
	hud.show_levelup_choice(new_level, player.stat_intimidation, player.stat_strength, player.stat_vigor, player.stat_agility, player.stat_might, player.stat_resilience, player.stat_reflexes, player.stat_dexterity, player.meta_resilience_unlocked, player.meta_reflexes_unlocked, player.meta_dexterity_unlocked)

func _process(delta: float) -> void:
	_update_shake(delta)

	if event_choosing:
		return

	if choosing_stat:
		_handle_stat_choice_input()
		return

	if game_over:
		if Input.is_key_pressed(KEY_R):
			_on_game_over_return_pressed()
		return

	if shop_open:
		_handle_shop_input()
		return

	if in_battle:
		_handle_battle(delta)
		return

	if wave_clearing:
		shop_open_delay_timer -= delta
		if shop_open_delay_timer <= 0.0:
			_open_shop()
		# Pause-key handling below runs even while get_tree().paused is true
		# (so the same key can un-pause), which would otherwise let the
		# shop's auto-open timer keep ticking behind an open pause menu --
		# the shop then force-opens on top of it, and menu_open is never
		# cleared, leaving a stuck PAUSED overlay after the shop closes.
		# Blocking the pause key for this brief window sidesteps it entirely.
		return

	var c_key: bool = settings.is_action_pressed("pause")
	# Settings is a sub-panel of the pause menu -- pressing the pause key
	# while it's open shouldn't also toggle the pause menu underneath (and
	# would otherwise unpause the game while Settings is still showing).
	if c_key and not prev_c_key and not settings_open:
		menu_open = not menu_open
		get_tree().paused = menu_open
		if menu_open:
			hud.show_menu()
		else:
			hud.hide_menu()
	prev_c_key = c_key

func _close_pause_menu() -> void:
	menu_open = false
	settings_open = false
	get_tree().paused = false
	hud.hide_menu()

func _on_settings_pressed() -> void:
	settings_open = true
	hud.show_settings()

func _on_settings_back_pressed() -> void:
	settings_open = false
	hud.hide_settings()

# The always-available 5 (Intimidation/Strength/Vigor/Agility/Might) plus
# Resilience/Reflexes/Dexterity in that fixed order, each only once its own
# skill-tree unlock is owned -- mirrors HUD.gd:show_levelup_choice's own
# button-building order exactly, so number keys 1-8 always match whatever's
# actually on screen.
func _levelup_choice_order() -> Array:
	var order := ["intimidation", "strength", "vigor", "agility", "might"]
	if player.meta_resilience_unlocked:
		order.append("resilience")
	if player.meta_reflexes_unlocked:
		order.append("reflexes")
	if player.meta_dexterity_unlocked:
		order.append("dexterity")
	return order

func _handle_stat_choice_input() -> void:
	var keys := {1: KEY_1, 2: KEY_2, 3: KEY_3, 4: KEY_4, 5: KEY_5, 6: KEY_6, 7: KEY_7, 8: KEY_8}
	var order: Array = _levelup_choice_order()
	for i in order.size():
		var key_num := i + 1
		var pressed := Input.is_key_pressed(keys[key_num])
		if pressed and not prev_num_key[key_num]:
			_on_levelup_choice_pressed(order[i])
		prev_num_key[key_num] = pressed

func _on_levelup_choice_pressed(stat_name: String) -> void:
	player.apply_bonus_stat(stat_name)
	hud.hide_levelup_choice()
	choosing_stat = false
	if shop_open:
		_refresh_shop_display()
	elif not in_battle and not game_over:
		# in_battle alone isn't proof the battle actually ended -- a killing
		# blow that also leveled up the player (both can fire synchronously
		# in the same attack-resolution call stack) clears in_battle as a
		# side effect of death, not victory. Un-pausing here would resume
		# live gameplay behind the still-showing game-over screen.
		get_tree().paused = false

func _handle_shop_input() -> void:
	# Number-key quick-buy only goes up to 9 -- offerings bigger than that
	# (already possible with SHOP_WEAPON_SLOTS at 3 plus armor and potions)
	# just fall back to clicking for the rest, rather than indexing a key
	# that was never defined and erroring out of the whole function before
	# it ever reaches the Enter-to-continue check below.
	var keys := {1: KEY_1, 2: KEY_2, 3: KEY_3, 4: KEY_4, 5: KEY_5, 6: KEY_6, 7: KEY_7, 8: KEY_8, 9: KEY_9}
	for i in range(1, min(current_shop_offering.size(), keys.size()) + 1):
		var pressed := Input.is_key_pressed(keys[i])
		if pressed and not prev_shop_num_key[i]:
			_on_shop_buy_pressed(i - 1)
		prev_shop_num_key[i] = pressed

	var reroll_pressed := Input.is_key_pressed(KEY_R)
	if reroll_pressed and not prev_reroll_key:
		_on_shop_reroll_pressed()
	prev_reroll_key = reroll_pressed

	var enter_key := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
	if enter_key and not prev_enter_key:
		_on_shop_continue_pressed()
	prev_enter_key = enter_key

func _on_shop_buy_pressed(index: int) -> void:
	if index < 0 or index >= current_shop_offering.size():
		return
	var item: Dictionary = current_shop_offering[index]
	var bought: bool
	match item.category:
		"armor":
			bought = player.try_buy_armor(item)
		"shield":
			var is_new_shield: bool = not player.owned_shields.has(item.id)
			bought = player.try_buy_shield(item)
			if bought and is_new_shield:
				_maybe_announce_unlock("shield:%s" % item.id.trim_prefix("shield_"), item.name, item.description)
		"potion":
			bought = player.try_buy_potion(item)
		_:
			var is_new_weapon: bool = not player.owned_weapons.has(item.id)
			bought = player.try_buy_weapon(item)
			if bought and is_new_weapon:
				var base_type: Dictionary = WeaponsScript.get_base_type(item)
				if not base_type.is_empty():
					_maybe_announce_unlock("weapon:%s" % base_type.id, base_type.name, base_type.description)
	play_sfx("purchase" if bought else "error")
	_refresh_shop_display()

func _on_shop_reroll_pressed() -> void:
	if _reroll_shop():
		play_sfx("purchase")
		_refresh_shop_display()
	else:
		play_sfx("error")

func _on_shop_continue_pressed() -> void:
	shop_open = false
	get_tree().paused = false
	hud.hide_shop()
	hud.show_message("")
	# Weapon/arrows can only change while the shop is open -- refresh the
	# overworld quiver display on the way out rather than after every single
	# buy/sell/equip inside the shop.
	hud.update_quiver(_player_has_bow(), player.owned_arrows)
	wave += 1
	hud.update_wave(wave)
	if not nothingness_rush_complete:
		current_world_index = _world_index_for_wave(wave)
	_apply_world_visuals()
	if shrine_effect_waves_remaining > 0:
		shrine_effect_waves_remaining -= 1
		if shrine_effect_waves_remaining == 0:
			player.temp_damage_bonus_pct = 0.0
	if not player.party_wolf.is_empty():
		wolf_waves_remaining -= 1
		if wolf_waves_remaining <= 0:
			player.party_wolf = {}
			hud.show_message("Your Traitor Wolf's loyalty fades -- it leaves your pack.")
	# Hardened: permanent max-HP growth per wave cleared THIS run.
	if player.meta_hardened_hp_per_wave > 0:
		player.max_health += player.meta_hardened_hp_per_wave
		player.heal(player.meta_hardened_hp_per_wave)
	_maybe_trigger_event()

# Random events (see scripts/Events.gd for flavor text). warrior_joins is
# excluded once the party is already full -- Recruiting past max_party_slots
# would just fall back to a coin consolation prize, so there's no point
# rolling it when it can't deliver its own payoff.
func _available_event_ids() -> Array:
	var ids: Array = EventsScript.EVENT_IDS.duplicate()
	if player.party_members.size() >= player.max_party_slots:
		ids.erase("warrior_joins")
	return ids

func _maybe_trigger_event() -> void:
	var available := _available_event_ids()
	if available.is_empty() or randf() >= EVENT_CHANCE:
		_spawn_wave()
		return
	var id: String = available[randi() % available.size()]
	var def: Dictionary = EventsScript.EVENTS[id]
	if def.auto:
		_apply_automatic_event(id)
		_spawn_wave()
		return
	active_event_id = id
	event_choosing = true
	get_tree().paused = true
	hud.show_event_choice(def.name, _build_event_description(id), def.yes_label, def.no_label)

# Split out from _maybe_trigger_event so both it and tooling/tests can
# deterministically build a given event's description (traveling_merchant's
# is dynamic -- it names whatever weapon just got rolled) without needing to
# fight EVENT_CHANCE/EVENT_IDS' randomness first.
func _build_event_description(id: String) -> String:
	var def: Dictionary = EventsScript.EVENTS[id]
	if id != "traveling_merchant":
		return def.description
	var base: Dictionary = WeaponsScript.UPGRADABLE_TYPES[randi() % WeaponsScript.UPGRADABLE_TYPES.size()]
	pending_event_weapon = WeaponsScript.make_variant(base, 3, player.luck_bonus)
	var price: int = int(round(player.get_weapon_price(pending_event_weapon) * MERCHANT_EVENT_DISCOUNT))
	# .name already carries its own tier prefix when notable (e.g.
	# "Masterwork Golden Spear") -- prepending tier_name again would double
	# it up.
	return "A traveling merchant offers you a %s for %d coins -- a steep discount." % [
		pending_event_weapon.name, price
	]

# Goblin Swarm / Elite Bounty: both apply as one-shot flags consumed by the
# very next _spawn_wave() call, rather than spawning enemies directly here --
# _spawn_wave() already owns the goblin_count/elite-roll logic for this wave.
func _apply_automatic_event(id: String) -> void:
	match id:
		"goblin_swarm":
			event_extra_goblins = SWARM_BONUS_GOBLINS
			player.add_coins(20)
			hud.show_message("A goblin swarm approaches! (+%d coins for the trouble)" % 20)
		"elite_bounty":
			event_force_elite = true
			hud.show_message("An elite has been spotted this wave...")

# Mirrors _on_levelup_choice_pressed's re-pause guard (Main.gd) -- the event
# choice is the only thing that was paused, so unless something else (the
# game-over screen) has taken over since, it's always safe to unpause here.
func _on_event_choice_pressed(accepted: bool) -> void:
	_resolve_event_choice(active_event_id, accepted)
	active_event_id = ""
	event_choosing = false
	hud.hide_event_choice()
	if not game_over:
		get_tree().paused = false
	_spawn_wave()

func _resolve_event_choice(id: String, accepted: bool) -> void:
	if not accepted:
		return
	match id:
		"warrior_joins":
			if player.party_members.size() >= player.max_party_slots:
				player.add_coins(30)
				hud.show_message("Your party has no room for them, so they wish you luck and split their coin with you. (+30 coins)")
			else:
				player.party_members.append({"name": "Warrior", "dmg_mult": 0.75})
				hud.show_message("A warrior joins your side for this journey!")
		"traveling_merchant":
			var price: int = int(round(player.get_weapon_price(pending_event_weapon) * MERCHANT_EVENT_DISCOUNT))
			if player.try_spend_coins(price):
				player.owned_weapons[pending_event_weapon.id] = true
				player._equip_weapon(pending_event_weapon)
				hud.show_message("You bought the %s." % pending_event_weapon.name)
			else:
				hud.show_message("Not enough coins for the merchant's offer.")
			pending_event_weapon = {}
		"ancient_shrine":
			if randf() < 0.5:
				player.temp_damage_bonus_pct = 0.20
				hud.show_message("The shrine blesses you! +20%% damage for %d waves." % SHRINE_EFFECT_WAVES)
			else:
				player.temp_damage_bonus_pct = -0.15
				hud.show_message("The shrine's energy sours! -15%% damage for %d waves." % SHRINE_EFFECT_WAVES)
			shrine_effect_waves_remaining = SHRINE_EFFECT_WAVES
		"wounded_traveler":
			if player.healing_items > 0:
				player.potion_queue.pop_front()
				player.healing_items = player.potion_queue.size()
				player.items_changed.emit(player.healing_items)
				player.add_coins(40)
				hud.show_message("They reward you generously. (+40 coins)")
			else:
				hud.show_message("You have nothing to spare them.")

# ---------------------------------------------------------------------------
# Tile battle (Advance Wars-style): triggered when an enemy reaches contact
# range with the player in the overworld. Gathers a small squad of nearby
# enemies, drops both sides onto a 6x6 grid with scattered terrain, and
# proceeds in strict alternating turns.
# ---------------------------------------------------------------------------

func trigger_battle(initial_enemy) -> void:
	if in_battle or game_over or shop_open or choosing_stat:
		return
	tutorial_active = not SaveDataScript.is_tutorial_completed_ever()
	tutorial_step = 0
	# A forced solo squad for the very first battle ever -- _gather_squad's
	# proximity gathering could otherwise turn a brand-new player's first
	# fight into a 2v1, which the tutorial's scripted hints don't account for.
	var squad := [initial_enemy] if tutorial_active else _gather_squad(initial_enemy)
	in_battle = true
	get_tree().paused = true
	_setup_battle_grid(squad)
	hud.show_battle(WORLDS[current_world_index].battle_bg)
	_focus_battle_main_menu()
	_refresh_battle_display()

# How much bigger a squad gets on top of its base size (MAX_BATTLE_ENEMIES_
# GOBLIN/TOUGH) -- further into the run (wave), stronger (level), and
# better-equipped (gear) all push toward the MAX_BATTLE_SQUAD_SIZE_CEILING.
func _squad_size_bonus() -> int:
	var difficulty_bonus: int = maxi(0, int(round((player.difficulty_mult - 1.0) * 2)))
	return (wave / 5) + (player.level / 5) + _gear_quality_score() + difficulty_bonus

# 0-2: +1 for a Masterwork-or-better equipped weapon, +1 for Steel Plate (or
# Dragonskin) armor. Deliberately reads the WORN gear, not everything owned
# -- a rolled Legendary weapon sitting unused in the shop shouldn't make
# fights harder.
func _gear_quality_score() -> int:
	var score := 0
	if player.current_weapon.get("tier_name", "") in ["Masterwork", "Legendary", "Mythic"]:
		score += 1
	if ArmorScript.TIERS.find(player.equipped_armor) >= 3:
		score += 1
	return score

func _gather_squad(initial_enemy) -> Array:
	# Boss fights are solo set pieces -- no escorts, no exceptions. Data-
	# driven off ENEMY_TRAITS' is_boss_tier flag (every miniboss/boss across
	# every world sets it) rather than a hardcoded name list, so a new boss
	# is automatically solo the moment its trait entry exists.
	if ENEMY_TRAITS.get(initial_enemy.get_display_name(), {}).get("is_boss_tier", false):
		return [initial_enemy]
	var initial_is_big: bool = ENEMY_TRAITS.get(initial_enemy.get_display_name(), {}).get("big_squad", false)
	var base_size: int = MAX_BATTLE_ENEMIES_TOUGH if initial_is_big else MAX_BATTLE_ENEMIES_GOBLIN
	var max_enemies: int = clampi(base_size + _squad_size_bonus(), base_size, MAX_BATTLE_SQUAD_SIZE_CEILING)
	var squad := [initial_enemy]
	var big_count := 1 if initial_is_big else 0
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	all_enemies.sort_custom(func(a, b): return initial_enemy.global_position.distance_to(a.global_position) < initial_enemy.global_position.distance_to(b.global_position))
	for e in all_enemies:
		if squad.size() >= max_enemies:
			break
		if e == initial_enemy or not is_instance_valid(e):
			continue
		if initial_enemy.global_position.distance_to(e.global_position) > BATTLE_GATHER_RADIUS:
			continue
		var is_big: bool = ENEMY_TRAITS.get(e.get_display_name(), {}).get("big_squad", false)
		# A goblin-tier-initiated battle stays goblin-tier -- tough units
		# never get pulled into it, no matter how close they wander.
		if is_big and (not initial_is_big or big_count >= MAX_BATTLE_TOUGH_UNITS):
			continue
		squad.append(e)
		if is_big:
			big_count += 1
	return squad

func _battle_player_move_range() -> int:
	var bonus: int = max(0, int(player.stat_agility - PlayerScript.AGILITY_START) / AGILITY_PER_EXTRA_MOVE)
	return PLAYER_BASE_MOVE_RANGE + bonus

func _setup_battle_grid(squad: Array) -> void:
	# A boss fight (always solo -- see _gather_squad) gets a bigger arena,
	# more room to maneuver against a lone, dangerous threat. Set before
	# anything below reads BATTLE_GRID_W/H.
	var is_boss_fight: bool = squad.size() == 1 and ENEMY_TRAITS.get(squad[0].get_display_name(), {}).get("is_boss_tier", false)
	BATTLE_GRID_W = BOSS_BATTLE_GRID_SIZE if is_boss_fight else DEFAULT_BATTLE_GRID_SIZE
	BATTLE_GRID_H = BATTLE_GRID_W

	battle_terrain.clear()
	battle_units.clear()
	battle_allies.clear()
	battle_turn = "player"
	battle_menu_state = "main"
	battle_move_trail = []
	battle_player_defending = false
	battle_player_taunting = false
	battle_skill_cooldown = 0
	battle_player_turns_to_skip = 0
	battle_momentum_stacks = 0
	player.disarmed_tile = Vector2i(-1, -1)
	player.pichaku_active = false
	player.second_chance_used_this_battle = false
	player.shield_vengeance_active = false
	player.berserk_turns_remaining = 0
	player.stealth_turns_remaining = 0
	battle_awaiting_evasion = false
	evasion_steps_left = 0
	player_poison_turns = 0
	player_poison_dmg = 0
	player_burning = false
	player_concussed_turns = 0
	player_bleeding = false
	player_blind_turns = 0
	battle_feared_by_index = -1
	battle_fear_cascade_depth = 0
	battle_rock_target = Vector2i(-1, -1)

	var used_tiles := {}
	battle_player_tile = Vector2i(0, BATTLE_GRID_H / 2)
	used_tiles[battle_player_tile] = true
	battle_target_index = 0
	battle_player_moves_left = _battle_player_move_range()
	player.reset_stamina()

	# The player's move allowance is small, so enemies still do most of the
	# closing of distance -- start them a few tiles off rather than at the
	# far edge, or a single-move-range unit like the Orc would take several
	# turns just to reach melee range.
	var enemy_col: int = max(1, BATTLE_GRID_W - 3)
	var enemy_rows := range(BATTLE_GRID_H)
	enemy_rows.shuffle()
	var scale_mult: float = 1.0 + (player.level - 1) * ENEMY_LEVEL_SCALING
	# Gnome HP scaling is a one-time snapshot of how big THIS fight's pack
	# started (unlike their damage bonus below, which is recomputed live
	# every turn from however many are still standing) -- counted once here
	# rather than per-Gnome inside the loop below.
	var gnome_pack_size := 0
	for s in squad:
		if s.get_display_name() == "Gnome":
			gnome_pack_size += 1
	for i in squad.size():
		var e = squad[i]
		var display_name: String = e.get_display_name()
		var traits: Dictionary = ENEMY_TRAITS.get(display_name, {})
		var size: int = traits.get("size", 1)
		var col: int = min(enemy_col, BATTLE_GRID_W - size)
		# A multi-tile unit's anchor is clamped so its whole footprint stays
		# on the grid -- but clamping a 2x2 Brute's row down (e.g. 5 -> 4)
		# can silently collide with whatever another squad member already
		# claimed at that row, since every unit shares roughly the same
		# column. Try each shuffled row in turn and take the first whose
		# full footprint is actually still free instead of trusting the
		# clamp alone; every cell it covers (not just the anchor) is then
		# reserved so terrain can't spawn inside it.
		var tile := Vector2i(col, min(enemy_rows[i % enemy_rows.size()], BATTLE_GRID_H - size))
		for row_candidate in enemy_rows:
			var candidate := Vector2i(col, min(row_candidate, BATTLE_GRID_H - size))
			var fits := true
			for cell in _footprint(candidate, size):
				if used_tiles.has(cell):
					fits = false
					break
			if fits:
				tile = candidate
				break
		for cell in _footprint(tile, size):
			used_tiles[cell] = true
		var elite_hp_mult: float = ELITE_HP_MULT if e.is_elite else 1.0
		var elite_dmg_mult: float = ELITE_DAMAGE_MULT if e.is_elite else 1.0
		# Read generically off whichever enemy instance this is, the same way
		# is_elite already is -- null (property doesn't exist on this script)
		# means "not applicable," not "unset," so it defaults to 1.0 rather
		# than erroring. Only Supreme Warlock's script defines this today
		# (see scripts/SupremeWarlock.gd), for its Nothingness rematch.
		var power_tier_raw = e.get("power_tier")
		var power_tier: float = power_tier_raw if power_tier_raw != null else 1.0
		# Baby/Hard/Apocalyptic (SaveData.gd:DIFFICULTIES) scale the same two
		# real combat numbers "enemy stats" already means everywhere else
		# (elite bonuses, level scaling) -- not enemy counts or move ranges.
		var scaled_hp: int = max(1, int(round(e.MAX_HEALTH * scale_mult * elite_hp_mult * player.difficulty_mult * power_tier)))
		if display_name == "Gnome" and gnome_pack_size > 1:
			scaled_hp += (gnome_pack_size - 1) * GNOME_HP_PER_PACKMATE
		var scaled_damage: int = max(1, int(round(e.get_contact_damage() * scale_mult * elite_dmg_mult * player.difficulty_mult * power_tier)))
		battle_units.append({
			"ref": e,
			"tile": tile,
			"hp": scaled_hp,
			"max_hp": scaled_hp,
			"move_range": traits.get("move_range", 2),
			"damage": scaled_damage,
			"name": display_name,
			"winding_up": false,
			"stunned": false,
			"size": size,
			"attack_range": traits.get("attack_range", 1),
			"is_elite": e.is_elite,
			# New status-effect fields (weapon specials rework) -- turn
			# counters follow the same "0/false = inactive" convention the
			# existing "stunned" bool already used, just generalized to
			# support a duration instead of a single skipped turn.
			"concussed_turns": 0,
			"frozen_turns": 0,
			"burning": false,
			"vulnerable_turns": 0,
			"aware_of_player": false,
			"armored": traits.get("armored", false),
			"disarmed_tile": Vector2i(-1, -1),
		})

	# Tutorial: pin the lone enemy onto the player's row, just past melee
	# range, instead of its normal random row -- otherwise the gap could
	# exceed a single Move's range and stall the scripted Move->Fight hint
	# sequence. Only ever runs when trigger_battle forced a solo squad.
	if tutorial_active and battle_units.size() == 1:
		var tut_tile := Vector2i(mini(battle_player_tile.x + PLAYER_BASE_MOVE_RANGE + 1, BATTLE_GRID_W - 1), battle_player_tile.y)
		used_tiles.erase(battle_units[0].tile)
		battle_units[0].tile = tut_tile
		used_tiles[tut_tile] = true

	_place_ally_units(used_tiles)

	# Base counts (rock 3 / water 3 / ledge 2 / cliff 1) were tuned for the
	# original 6x6 grid -- scaled by area so an 8x8 or 15x15 battlefield
	# keeps the same terrain density instead of feeling emptier as the grid
	# grows. int(round(...)) with a floor of the original count since every
	# current grid size is at least as big as the 6x6 baseline.
	var terrain_scale: float = float(BATTLE_GRID_W * BATTLE_GRID_H) / 36.0
	_place_terrain("rock", max(3, int(round(3 * terrain_scale))), used_tiles)
	_place_terrain("water", max(3, int(round(3 * terrain_scale))), used_tiles, true, false)
	_place_terrain("ledge", max(2, int(round(2 * terrain_scale))), used_tiles, false, true)
	_place_terrain("cliff", max(1, int(round(1 * terrain_scale))), used_tiles, false, true)
	# Whichever RESERVED_TERRAIN_TYPES the current world's flavor calls for
	# (empty for Plains/Nothingness, which stick to the base 4 above) --
	# _place_terrain's signature is already generic over terrain type, so no
	# reserved kind needs any special-casing here.
	for kind in WORLDS[current_world_index].terrain:
		_place_terrain(kind, max(2, int(round(2 * terrain_scale))), used_tiles)
	_prevent_boxed_in_units()

# Seats the player's recruited party onto the grid before terrain is placed
# (mirrors how enemy tiles are reserved first) -- candidates are drawn from
# the player's own side of the grid (columns 0-1) so allies start clustered
# near the player rather than scattered toward the enemy squad.
func _place_ally_units(used_tiles: Dictionary) -> void:
	var roster: Array = []
	for member in player.party_members:
		# Warband (Warrior + Merchant convergence): recruited party members
		# hit harder, but not the wolf companion -- it's not a "recruited
		# mercenary" the way Blade Ally/Warrior are.
		roster.append({"name": member.name, "dmg_mult": member.dmg_mult + player.meta_warband_bonus, "move_range": ALLY_MOVE_RANGE, "max_hp_pct": ALLY_MAX_HP_PCT})
	if not player.party_wolf.is_empty():
		roster.append({"name": player.party_wolf.name, "dmg_mult": player.party_wolf.dmg_mult, "move_range": ALLY_WOLF_MOVE_RANGE, "max_hp_pct": WOLF_ALLY_MAX_HP_PCT})
	if roster.is_empty():
		return

	var candidates := []
	for x in range(2):
		for y in range(BATTLE_GRID_H):
			var t := Vector2i(x, y)
			if not used_tiles.has(t):
				candidates.append(t)
	candidates.shuffle()
	# Extremely unlikely fallback if columns 0-1 somehow can't fit everyone
	# (only the player plus up to 4 allies ever compete for those 12 tiles)
	# -- scan the whole grid rather than skip seating an ally.
	if candidates.size() < roster.size():
		for x in range(BATTLE_GRID_W):
			for y in range(BATTLE_GRID_H):
				var t := Vector2i(x, y)
				if not used_tiles.has(t) and not candidates.has(t):
					candidates.append(t)

	for i in roster.size():
		var entry: Dictionary = roster[i]
		var tile: Vector2i = candidates[i]
		used_tiles[tile] = true
		var max_hp: int = max(1, int(round(player.max_health * float(entry.max_hp_pct))))
		battle_allies.append({
			"tile": tile,
			"hp": max_hp,
			"max_hp": max_hp,
			# Might: +0.5% ally damage per point owned, applied to both
			# recruited party members and the wolf companion alike.
			"dmg_mult": entry.dmg_mult * (1.0 + player.stat_might * MIGHT_ALLY_DAMAGE_PCT_PER_POINT),
			"name": entry.name,
			"move_range": entry.move_range,
			"attack_range": ALLY_ATTACK_RANGE,
		})

# Rock is the only terrain type that actually blocks movement outright (water
# just pushes, ledges/cliffs are one-way but still crossable) -- with random
# placement, nothing stopped 3 rocks from occasionally landing on literally
# every open side of a tile, sealing it in. Originally this only checked
# tiles occupied at setup time (the player's/enemies'/allies' starting
# tiles), which missed the case that actually softlocks a run: a tile
# nobody starts on yet, that a unit later walks or one-way-vaults (a ledge/
# cliff never lets you go back the way you came) INTO mid-battle, only to
# find every other side is rock too -- confirmed from a real screenshot
# where the player ended up pinned in a grid corner with rock on every
# in-bounds side. Sweeping every tile on the grid at setup time, not just
# occupied ones, guarantees no such trap can ever exist in the first place,
# regardless of how a unit later reaches it.
func _prevent_boxed_in_units() -> void:
	for x in BATTLE_GRID_W:
		for y in BATTLE_GRID_H:
			var tile := Vector2i(x, y)
			var neighbors := []
			for dir in CARDINAL_DIRS:
				var n: Vector2i = tile + dir
				if _in_battle_bounds(n):
					neighbors.append(n)
			var all_blocked := true
			for n in neighbors:
				var terrain = battle_terrain.get(n, null)
				# Rock/Rubble are the only tiles _resolve_battle_step ever
				# fully blocks now -- a ledge/cliff is walkable from any
				# direction (only moving WITH its own dir triggers the
				# one-way vault), so it's no longer a dead end from "the
				# wrong side" the way a rock is.
				var blocked: bool = terrain != null and terrain.type in ["rock", "rubble"]
				if not blocked:
					all_blocked = false
					break
			if all_blocked and not neighbors.is_empty():
				battle_terrain.erase(neighbors[0])

func _place_terrain(kind: String, count: int, used_tiles: Dictionary, needs_push: bool = false, needs_dir: bool = false) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 60:
		attempts += 1
		var t := Vector2i(randi_range(0, BATTLE_GRID_W - 1), randi_range(0, BATTLE_GRID_H - 1))
		if used_tiles.has(t) or battle_terrain.has(t):
			continue
		var entry := {"type": kind}
		if needs_push:
			entry.push_dir = CARDINAL_DIRS[randi() % CARDINAL_DIRS.size()]
		if needs_dir:
			entry.dir = CARDINAL_DIRS[randi() % CARDINAL_DIRS.size()]
		battle_terrain[t] = entry
		used_tiles[t] = true
		placed += 1

func _in_battle_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < BATTLE_GRID_W and t.y < BATTLE_GRID_H

# A random accessible tile to fling a disarmed combatant's weapon to --
# shared by both the player-disarm (Spear's Target Practice miss, Dagger's
# Knife Throw) and enemy-disarm (Knuckle Gloves' Wrist Strike) specials.
# Empty and terrain-free so it's always actually reachable on foot.
func _pick_disarm_tile() -> Vector2i:
	var candidates := []
	for x in BATTLE_GRID_W:
		for y in BATTLE_GRID_H:
			var t := Vector2i(x, y)
			if not _battle_tile_occupied(t) and not battle_terrain.has(t):
				candidates.append(t)
	if candidates.is_empty():
		return battle_player_tile
	return candidates[randi() % candidates.size()]

# Clears the player's disarmed state the instant they're standing on the
# tile their weapon landed on -- called after every Move step, plus once
# more at the top of the player's own turn as a safety net.
func _check_disarm_reclaimed() -> void:
	if player.disarmed_tile != Vector2i(-1, -1) and battle_player_tile == player.disarmed_tile:
		player.disarmed_tile = Vector2i(-1, -1)
		hud.battle_log("You reclaim your weapon!")

# The cells a unit's tile actually covers -- 1 for everything except a 2x2
# unit like the Brute, anchored at its top-left corner.
func _footprint(tile: Vector2i, size: int) -> Array:
	if size <= 1:
		return [tile]
	var cells := []
	for dx in size:
		for dy in size:
			cells.append(tile + Vector2i(dx, dy))
	return cells

# Manhattan distance from `target` to the NEAREST cell of `footprint` --
# used to check adjacency/range against a multi-tile unit from either side.
func _footprint_dist(footprint: Array, target: Vector2i) -> int:
	var best := 9999
	for cell in footprint:
		var d: int = abs(cell.x - target.x) + abs(cell.y - target.y)
		if d < best:
			best = d
	return best

# ignore_ref excludes a unit's own current cells from the check -- needed
# when that same unit is asking whether it can move somewhere its new
# footprint overlaps its old one. ignore_tile does the same for an ally
# (which has no CharacterBody2D ref to key off of) -- pass its own current
# tile so it doesn't block its own step.
func _battle_tile_occupied(t: Vector2i, ignore_ref = null, ignore_tile = null) -> bool:
	if t == battle_player_tile:
		return true
	for u in battle_units:
		if u.ref == ignore_ref:
			continue
		for cell in _footprint(u.tile, u.get("size", 1)):
			if cell == t:
				return true
	for a in battle_allies:
		if ignore_tile != null and a.tile == ignore_tile:
			continue
		if a.tile == t:
			return true
	return false

# A Fae Hut's spawn lands on whichever cardinal-adjacent tile is actually
# free -- unoccupied AND not a Rock/Rubble tile it'd otherwise spawn stuck
# inside of. Sentinel (-1,-1) if the hut is fully boxed in.
func _find_empty_tile_near(origin: Vector2i) -> Vector2i:
	var candidates: Array = CARDINAL_DIRS.duplicate()
	candidates.shuffle()
	for dir in candidates:
		var t: Vector2i = origin + dir
		if not _in_battle_bounds(t) or _battle_tile_occupied(t):
			continue
		var terrain = battle_terrain.get(t, null)
		if terrain != null and terrain.type in ["rock", "rubble"]:
			continue
		return t
	return Vector2i(-1, -1)

func _player_long_range_equipped() -> bool:
	return player.current_weapon.get("long_range", false)

# The Spear can hit diagonally-adjacent enemies, unlike every other weapon
# (matches on the id PREFIX since a rolled variant's id is always
# "spear_<tier>_<material>" or "spear_mythic", never bare "spear").
func _player_has_spear() -> bool:
	return player.current_weapon.get("id", "").begins_with("spear")

# Special arrows (see WeaponsScript.ARROW_TYPES) are only purchasable and
# usable from their own battle button while the Bow is equipped -- same id-
# prefix matching as _player_has_spear, for the same reason (a rolled Bow
# variant's id is never bare "bow").
func _player_has_bow() -> bool:
	return player.current_weapon.get("id", "").begins_with("bow")

func _player_has_hand_picks() -> bool:
	return player.current_weapon.get("id", "").begins_with("hand_picks")

# Gates the Dagger's sneak-crit bonus (KNIFE_STEALTH_CRIT_BONUS) -- same
# id-prefix matching as the other _player_has_* checks above.
func _player_has_dagger() -> bool:
	return player.current_weapon.get("id", "").begins_with("dagger")

# Cardinal-adjacent Rock/Rubble tiles -- the only thing Hand Picks' Mine
# action can ever target, matching the same "melee, range 1" reach a plain
# attack has (Hand Picks has no long_range flag).
func _targetable_rock_tiles() -> Array:
	var result := []
	for dir in CARDINAL_DIRS:
		var t: Vector2i = battle_player_tile + dir
		var terrain = battle_terrain.get(t, null)
		if terrain != null and terrain.type in ["rock", "rubble"]:
			result.append(t)
	return result

# Mirrors _effective_target_index's shape: the player's explicitly clicked
# rock if it's still there and still in reach, otherwise whichever
# targetable rock comes first -- never an invalid/stale selection.
func _effective_rock_target() -> Vector2i:
	var targetable := _targetable_rock_tiles()
	if targetable.is_empty():
		return Vector2i(-1, -1)
	if battle_rock_target in targetable:
		return battle_rock_target
	return targetable[0]

# Clicking a battle tile (see HUD.gd's per-tile gui_input) always reports
# here regardless of what's actually on it -- only a currently-targetable
# rock during the player's own turn does anything with the click.
func _on_rock_target_selected(tile: Vector2i) -> void:
	if battle_turn != "player" or not tile in _targetable_rock_tiles():
		return
	battle_rock_target = tile
	_refresh_battle_display()

func _resolve_mine_rock() -> void:
	var target := _effective_rock_target()
	if target == Vector2i(-1, -1):
		hud.battle_log("No rock in reach.")
		return
	var broken_name: String = "rubble" if battle_terrain[target].type == "rubble" else "rock"
	battle_terrain.erase(target)
	battle_rock_target = Vector2i(-1, -1)
	play_sfx("mine")
	hud.battle_log("You break the %s apart!" % broken_name)
	_end_player_turn()

func _has_adjacent_rock(t: Vector2i) -> bool:
	for dir in CARDINAL_DIRS:
		var terrain = battle_terrain.get(t + dir, null)
		# Rubble (reserved terrain) is functionally rock -- same cover.
		if terrain != null and terrain.type in ["rock", "rubble"]:
			return true
	return false

# Attempts one step in `dir` from `from`. Resolves rocks/rubble (blocked),
# ledges and cliffs (one-way only, forced hop to the tile beyond -- like a
# Pokemon ledge), reports whether the mover should take cliff-fall damage,
# and (reserved terrain) whether landing on ice slides an extra tile or
# landing on caltrops costs an extra point of move budget.
func _resolve_battle_step(from: Vector2i, dir: Vector2i, ignore_tile = null) -> Dictionary:
	var blocked := {"tile": from, "moved": false, "fell": false}
	var target := from + dir
	if not _in_battle_bounds(target) or _battle_tile_occupied(target, null, ignore_tile):
		return blocked
	var terrain = battle_terrain.get(target, null)
	if terrain != null and terrain.type in ["rock", "rubble"]:
		return blocked
	if terrain != null and (terrain.type == "ledge" or terrain.type == "cliff"):
		if dir != terrain.dir:
			# Approaching from any angle other than the tile's own one-way
			# direction just walks onto it and stops there -- no vault, no
			# fall damage. The vault below (jump clean over, cliffs dealing
			# fall damage) is reserved for moving WITH the tile's flow,
			# preserving the one-way "Pokemon ledge" drop-down specifically
			# in its intended direction rather than blocking every other
			# approach outright.
			return {"tile": target, "moved": true, "fell": false}
		var landing := target + dir
		if not _in_battle_bounds(landing) or _battle_tile_occupied(landing, null, ignore_tile):
			return blocked
		var landing_terrain = battle_terrain.get(landing, null)
		if landing_terrain != null and landing_terrain.type in ["rock", "rubble"]:
			return blocked
		var fell := false
		if terrain.type == "cliff":
			var lands_in_water: bool = landing_terrain != null and landing_terrain.type == "water"
			# NOTE: "unless wearing specific armor" isn't implemented yet --
			# armor equipping doesn't exist in Player.gd yet. Only the
			# water-landing exception applies for now.
			if not lands_in_water:
				fell = true
		return {"tile": landing, "moved": true, "fell": fell}
	if terrain != null and terrain.type == "ice":
		# A single extra slide, kept deliberately simple -- lands on plain
		# ground or water/ice only; sliding onto a ledge/cliff/caltrops mid-
		# slide just stops short of them rather than resolving their own
		# entry logic too.
		var slide_target := target + dir
		var slide_terrain = battle_terrain.get(slide_target, null)
		var slide_ok: bool = _in_battle_bounds(slide_target) and not _battle_tile_occupied(slide_target, null, ignore_tile) and (slide_terrain == null or slide_terrain.type in ["water", "ice"])
		if slide_ok:
			return {"tile": slide_target, "moved": true, "fell": false}
		return {"tile": target, "moved": true, "fell": false}
	if terrain != null and terrain.type == "caltrops":
		return {"tile": target, "moved": true, "fell": false, "extra_cost": true}
	return {"tile": target, "moved": true, "fell": false}

# Movement for a multi-tile, terrain-ignoring unit (the Brute): the whole
# footprint shifts together, checked only against grid bounds and other
# units' cells -- no rocks, ledges, cliffs, or water in its way at all.
func _resolve_big_unit_step(tile: Vector2i, size: int, dir: Vector2i, self_ref) -> Dictionary:
	var new_tile := tile + dir
	for cell in _footprint(new_tile, size):
		if not _in_battle_bounds(cell) or _battle_tile_occupied(cell, self_ref):
			return {"tile": tile, "moved": false}
	return {"tile": new_tile, "moved": true}

# unit is an empty Dictionary for the player, or a battle_units entry for an
# enemy -- same is_empty()-means-player convention _apply_terrain_tick uses.
func _apply_water_push(tile: Vector2i, unit: Dictionary = {}) -> Vector2i:
	var terrain = battle_terrain.get(tile, null)
	if terrain == null or terrain.type != "water":
		return tile
	# Burn only ever clears by touching water, no natural duration -- this is
	# the single chokepoint every water interaction (successful push or not)
	# already flows through, so it's checked here regardless of whether the
	# push itself actually succeeds below.
	if unit.is_empty():
		player_burning = false
	else:
		unit.burning = false
	var pushed: Vector2i = tile + terrain.push_dir
	if not _in_battle_bounds(pushed) or _battle_tile_occupied(pushed):
		return tile
	var pushed_terrain = battle_terrain.get(pushed, null)
	if pushed_terrain != null and pushed_terrain.type == "rock":
		return tile
	return pushed

# Reserved terrain (see RESERVED_TERRAIN_TYPES): resolves the "something
# happens if you end your turn standing here" effects -- Embers (arms Burn,
# see BURN_DAMAGE_DIVISOR), Poison Bog (arms a lingering DOT, mirrors
# poison_turns/poison_dmg but ticks separately at the top of a later turn,
# not here), Quicksand (arms a skipped next turn), Healing Spring (immediate
# heal), and
# Crumbling Floor (the tile itself gives way, permanently, the first time).
# unit is an empty Dictionary for the player, or a battle_units entry for an
# enemy -- allies aren't covered, they don't carry per-unit status turn-
# counters at all yet. Called alongside _apply_water_push, same call sites.
func _apply_terrain_tick(tile: Vector2i, unit: Dictionary = {}) -> void:
	var terrain = battle_terrain.get(tile, null)
	if terrain == null:
		return
	var is_player: bool = unit.is_empty()
	var who: String = "you" if is_player else "the %s" % unit.name
	match terrain.type:
		"embers":
			# Sets Burn instead of a one-off flat hit -- see the Burn rework
			# notes above BURN_DAMAGE_DIVISOR. Cleared only by touching water
			# (_apply_water_push), not by a turn counter.
			if is_player:
				player_burning = true
			else:
				unit.burning = true
			hud.battle_log("The embers set %s alight!" % who)
		"poison_bog":
			if is_player:
				player_poison_turns = POISON_TURNS
				player_poison_dmg = max(1, int(round(player.max_health * POISON_DAMAGE_PCT)))
			else:
				unit.poison_turns = POISON_TURNS
				unit.poison_dmg = max(1, int(round(float(unit.max_hp) * POISON_DAMAGE_PCT)))
			hud.battle_log("The bog's fumes poison %s!" % who)
		"quicksand":
			if is_player:
				battle_player_turns_to_skip += 1
			else:
				unit["stunned"] = true
			hud.battle_log("The quicksand mires %s in place!" % who)
		"spring":
			if is_player:
				player.heal(SPRING_HEAL_AMOUNT)
			else:
				unit.hp = min(unit.max_hp, unit.hp + SPRING_HEAL_AMOUNT)
			hud.battle_log("The spring's waters heal %s for %d HP!" % [who, SPRING_HEAL_AMOUNT])
		"crumbling":
			battle_terrain[tile] = {"type": "rock"}
			hud.battle_log("The floor crumbles away beneath %s!" % who)

# max_range 1 is melee (a spear/bow/Archer at range 2+ ignores the ledge/
# cliff directionality check entirely -- shooting over one is fine, walking
# onto one isn't). Ranges above 2 (the Archer's 5) reuse the exact same
# straight-line-only, rock-blocks-the-line rule, just walked further.
func _can_battle_attack(attacker_tile: Vector2i, target_tile: Vector2i, max_range: int, ignore_line: bool = false) -> bool:
	var diff := target_tile - attacker_tile
	var dist: int = abs(diff.x) + abs(diff.y)
	if dist < 1 or dist > max_range:
		return false
	# The Apprentice Mage's rework -- a caster striking on a diagonal/offset
	# line rather than a bowstring's dead-straight one -- skips the whole
	# axis-aligned-and-unblocked-by-rocks check every other ranged attacker
	# still needs.
	if dist >= 2 and not ignore_line:
		if diff.x != 0 and diff.y != 0:
			return false
		var step := Vector2i(sign(diff.x), sign(diff.y))
		var cursor := attacker_tile + step
		while cursor != target_tile:
			var mid_terrain = battle_terrain.get(cursor, null)
			# Thicket (reserved terrain) blocks a shot through it without
			# blocking movement the way Rock/Rubble do; Rubble blocks both.
			if mid_terrain != null and mid_terrain.type in ["rock", "rubble", "thicket"]:
				return false
			cursor += step
	if max_range <= 1:
		var target_terrain = battle_terrain.get(target_tile, null)
		if target_terrain != null and (target_terrain.type == "ledge" or target_terrain.type == "cliff"):
			# Only the exact opposite of the tile's own vault direction is
			# blocked -- reaching up from below the drop. Approaching from
			# either side (perpendicular to dir) never involved the drop at
			# all and was wrongly blocked before this fix; the vault
			# direction itself (diff == dir) was already fine.
			if diff == -target_terrain.dir:
				return false
	return true

# General-purpose vision check between two tiles, used by the Stealth
# detection system (_enemy_currently_sees_player, hover-LOS). Deliberately
# separate from _can_battle_attack's own line check above -- that one is
# axis-restricted (diagonals always blocked), tuned for arrow/spear fire, not
# appropriate for "can this enemy perceive the player," which should work in
# any direction. Bresenham line trace, blocked by the same terrain types a
# ranged attack already respects.
func _has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var dx: int = abs(to.x - from.x)
	var dy: int = -abs(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx + dy
	var cursor := from
	while cursor != to:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			cursor.x += sx
		if e2 <= dx:
			err += dx
			cursor.y += sy
		if cursor == to:
			break
		var mid_terrain = battle_terrain.get(cursor, null)
		if mid_terrain != null and mid_terrain.type in ["rock", "rubble", "thicket"]:
			return false
	return true

# The LIVE geometric check -- "could this unit spot the player RIGHT NOW,"
# recomputed fresh every call. Used only to latch battle_units' sticky
# "aware_of_player" field (see _update_enemy_awareness) and to drive the
# hover-LOS visualization; every other system reads the latched flag via
# _enemy_currently_sees_player below instead, so a unit's awareness can't
# flicker off just because the player stepped behind a rock for a moment.
func _enemy_can_see_player_now(u: Dictionary) -> bool:
	var sight_range: int = STEALTH_SIGHT_RANGE if player.stealth_turns_remaining > 0 else ENEMY_SIGHT_RANGE
	var footprint: Array = _footprint(u.tile, u.get("size", 1))
	if _footprint_dist(footprint, battle_player_tile) > sight_range:
		return false
	return _has_line_of_sight(u.tile, battle_player_tile)

# Called at the top of every enemy turn (_process_enemy_turn) and continuously
# during the player's own turn (_refresh_battle_display) so newly-in-range
# units get spotted the moment it happens, not a turn late. Once set, a
# unit's aware_of_player never resets to false for the rest of the battle
# (see Main.gd's per-unit battle_units dict) -- being spotted is permanent,
# same as "upon being spotted" reads for a real stealth mechanic. Skips
# boss-tier units entirely; _enemy_currently_sees_player below already
# treats them as always-aware regardless of this stored flag.
func _update_enemy_awareness() -> void:
	for u in battle_units:
		if u.get("aware_of_player", false):
			continue
		if ENEMY_TRAITS.get(u.name, {}).get("is_boss_tier", false):
			continue
		if _enemy_can_see_player_now(u):
			u.aware_of_player = true

# Single source of truth for "does this enemy currently perceive the
# player" -- drives AI targeting/wander, the red "!" indicator, hover-LOS,
# and the Dagger sneak-crit bonus alike, so none of those can ever disagree.
# Boss-tier enemies are always aware; every other unit reads its own sticky
# aware_of_player flag (latched by _update_enemy_awareness, or set directly
# by Taunt/a landed hit -- see _battle_player_taunt/_apply_single_hit).
func _enemy_currently_sees_player(u: Dictionary) -> bool:
	if ENEMY_TRAITS.get(u.name, {}).get("is_boss_tier", false):
		return true
	return u.get("aware_of_player", false)

func _handle_battle(_delta: float) -> void:
	# Phantom Guard's evasion reposition happens mid-"enemy" turn (see
	# _prompt_evasion_reposition), so this is checked ahead of the
	# battle_turn == "player" gate below rather than folded into the "move"
	# menu-state branch, which only ever runs during the player's own turn.
	if battle_awaiting_evasion:
		var evasion_actions := {"move_up": Vector2i(0, -1), "move_down": Vector2i(0, 1), "move_left": Vector2i(-1, 0), "move_right": Vector2i(1, 0)}
		for action in evasion_actions:
			var evasion_pressed: bool = settings.is_action_pressed(action)
			if evasion_pressed and not prev_battle_keys.get(action, false):
				_try_evasion_step(evasion_actions[action])
			prev_battle_keys[action] = evasion_pressed
		var evasion_confirm_pressed: bool = settings.is_action_pressed("confirm")
		if evasion_confirm_pressed and not prev_battle_keys.get("confirm", false):
			evasion_confirmed.emit()
		prev_battle_keys["confirm"] = evasion_confirm_pressed
		if in_battle:
			_refresh_battle_display()
		return

	if battle_turn != "player":
		return

	# Menu actions are click-driven. Z also universally activates whatever
	# button currently has keyboard focus (bound as an extra "ui_accept" key
	# in TitleScreen.gd, same as Enter/Space natively) -- that alone covers
	# "Select" for Main/Fight, since their buttons stay focusable. Move's
	# Confirm/Cancel deliberately can't take focus (arrows are needed purely
	# for grid movement there, not focus-hopping between two buttons), so Z
	# is wired explicitly there instead of relying on focus. X has no
	# built-in engine equivalent at all, so "Back" is always explicit.
	if battle_menu_state == "move":
		var move_actions := {"move_up": Vector2i(0, -1), "move_down": Vector2i(0, 1), "move_left": Vector2i(-1, 0), "move_right": Vector2i(1, 0)}
		for action in move_actions:
			var pressed: bool = settings.is_action_pressed(action)
			if pressed and not prev_battle_keys.get(action, false):
				_try_battle_player_move(move_actions[action])
			prev_battle_keys[action] = pressed

		var confirm_pressed: bool = settings.is_action_pressed("confirm")
		if confirm_pressed and not prev_battle_keys.get("confirm", false):
			_on_battle_move_action("confirm")
		prev_battle_keys["confirm"] = confirm_pressed

		var cancel_pressed: bool = settings.is_action_pressed("cancel")
		if cancel_pressed and not prev_battle_keys.get("cancel", false):
			_on_battle_move_action("cancel")
		prev_battle_keys["cancel"] = cancel_pressed
	elif battle_menu_state == "fight":
		var back_pressed: bool = settings.is_action_pressed("cancel")
		if back_pressed and not prev_battle_keys.get("cancel", false):
			_on_battle_fight_action("back")
		prev_battle_keys["cancel"] = back_pressed
	elif battle_menu_state == "arrow":
		var back_pressed: bool = settings.is_action_pressed("cancel")
		if back_pressed and not prev_battle_keys.get("cancel", false):
			_on_battle_arrow_action("back")
		prev_battle_keys["cancel"] = back_pressed

	if in_battle:
		_refresh_battle_display()

# Shared by both the battle keyboard shortcuts and the clickable HUD buttons,
# so the two input paths can never drift out of sync with each other.
func _on_battle_main_action(action: String) -> void:
	if battle_turn != "player":
		return
	if tutorial_active and not _tutorial_action_allowed(action):
		hud.battle_log("Follow the tutorial hint above.")
		return
	match action:
		"move":
			if battle_player_moves_left <= 0:
				hud.battle_log("No moves left this turn.")
				return
			battle_menu_state = "move"
			battle_move_undo_tile = battle_player_tile
			battle_move_undo_moves_left = battle_player_moves_left
			battle_move_undo_health = player.health
			battle_move_trail = []
			# Move's Confirm/Cancel refuse focus on purpose, but whatever WAS
			# focused before (e.g. the Move button itself) would otherwise
			# stay focused while hidden -- and since Z is bound to Godot's
			# native "ui_accept", pressing it here would silently re-press
			# that stale hidden button too, alongside the real Move-mode
			# handling below. Releasing focus here avoids that.
			get_viewport().gui_release_focus()
			_refresh_battle_display()
		"fight":
			battle_menu_state = "fight"
			_focus_battle_fight_menu()
			_refresh_battle_display()
		"item":
			_battle_player_item()
		"defend":
			_battle_player_defend()
		"skill":
			_battle_player_skill()
		"arrow":
			battle_menu_state = "arrow"
			_focus_battle_arrow_menu()
			_refresh_battle_display()
		"tactics":
			battle_menu_state = "tactics"
			_focus_battle_tactics_menu()
			_refresh_battle_display()
		"flee":
			_battle_flee()

func _on_battle_fight_action(action: String) -> void:
	if battle_turn != "player":
		return
	if tutorial_active and tutorial_step == 1 and action != "attack" and action != "back":
		hud.battle_log("Try a regular Attack.")
		return
	match action:
		"attack":
			_battle_player_fight()
		"heavy":
			_battle_player_heavy_attack()
		"special_0":
			_battle_player_special(0)
		"special_1":
			_battle_player_special(1)
		"special_2":
			_battle_player_special(2)
		"mine":
			_resolve_mine_rock()
		"back":
			battle_menu_state = "main"
			_focus_battle_main_menu()
			_refresh_battle_display()

func _on_battle_arrow_action(action: String) -> void:
	if battle_turn != "player":
		return
	match action:
		"flame", "freeze", "bomb":
			_battle_player_arrow(action)
		"back":
			battle_menu_state = "main"
			_focus_battle_main_menu()
			_refresh_battle_display()

func _on_battle_tactics_action(action: String) -> void:
	if battle_turn != "player":
		return
	match action:
		"taunt":
			_battle_player_taunt()
		"stealth":
			_battle_player_stealth()
		"back":
			battle_menu_state = "main"
			_focus_battle_main_menu()
			_refresh_battle_display()

func _on_battle_move_action(action: String) -> void:
	if battle_turn != "player":
		return
	match action:
		"confirm":
			if tutorial_active and tutorial_step == 0:
				_advance_tutorial_hint()
			battle_menu_state = "main"
			battle_move_trail = []
			_focus_battle_main_menu()
			_refresh_battle_display()
		"cancel":
			battle_player_tile = battle_move_undo_tile
			battle_player_moves_left = battle_move_undo_moves_left
			player.restore_health(battle_move_undo_health)
			battle_menu_state = "main"
			battle_move_trail = []
			hud.battle_log("Movement undone.")
			_focus_battle_main_menu()
			_refresh_battle_display()

# Grabs an initial keyboard-focus target whenever a menu becomes visible, so
# arrow-key navigation has somewhere to start from without needing a prior
# mouse click.
func _focus_battle_main_menu() -> void:
	if tutorial_active:
		hud.battle_main_buttons[["move", "fight", "defend"][tutorial_step]].grab_focus()
	else:
		hud.battle_main_buttons["move"].grab_focus()

func _focus_battle_fight_menu() -> void:
	hud.battle_fight_buttons["attack"].grab_focus()

func _focus_battle_arrow_menu() -> void:
	hud.battle_arrow_buttons["flame"].grab_focus()

func _focus_battle_tactics_menu() -> void:
	hud.battle_tactics_buttons["taunt"].grab_focus()

func _try_battle_player_move(dir: Vector2i) -> void:
	if battle_player_moves_left <= 0:
		return
	var result := _resolve_battle_step(battle_player_tile, dir)
	if not result.moved:
		return
	battle_player_tile = result.tile
	# Caltrops (reserved terrain) cost an extra point of move budget to cross.
	battle_player_moves_left -= 2 if result.get("extra_cost", false) else 1
	battle_move_trail.append({"tile": battle_player_tile, "dir": dir})
	_check_disarm_reclaimed()
	_apply_bleed_move_damage()
	if result.fell:
		if player.equipped_armor.get("negates_fall_damage", false):
			hud.battle_log("Your %s lets you shrug off the fall." % player.equipped_armor.name)
		else:
			var dmg := int(round(player.max_health * CLIFF_FALL_DAMAGE_PCT))
			player.take_battle_damage(dmg)
			hud.battle_log("You fall! Took %d damage." % dmg)

# Bleeding: %-of-max-HP lost per tile moved -- shared by every way the
# player can move a single step in battle (_try_battle_player_move and the
# evasion reposition below both call this after a successful step).
func _apply_bleed_move_damage() -> void:
	if not player_bleeding:
		return
	var dmg: int = max(1, int(round(player.max_health * BLEED_MOVE_DAMAGE_PCT)))
	player.take_battle_damage(dmg)
	hud.battle_log("Bleeding, the movement costs you %d HP." % dmg)

func _targetable_indices() -> Array:
	var max_range := 2 if _player_long_range_equipped() else 1
	var ignore_line: bool = _player_has_spear()
	var result := []
	for i in battle_units.size():
		var u: Dictionary = battle_units[i]
		var size: int = u.get("size", 1)
		var in_range: bool
		if size > 1:
			# A multi-tile unit is reachable if the player is close enough
			# to ANY of its cells -- the geometry helpers above assume a
			# single-tile attacker/defender, so this bypasses them entirely.
			in_range = _footprint_dist(_footprint(u.tile, size), battle_player_tile) <= max_range
		else:
			in_range = _can_battle_attack(battle_player_tile, u.tile, max_range, ignore_line)
		if in_range:
			result.append(i)
	return result

# Resolves which enemy an attack would actually land on: the player's chosen
# target if it's still in range, otherwise the nearest in-range fallback.
func _effective_target_index() -> int:
	var targetable := _targetable_indices()
	if targetable.is_empty():
		return -1
	if battle_target_index in targetable:
		return battle_target_index
	return targetable[0]

# Clicking an enemy's battle sprite (HUD.gd's enemy_target_selected) sets it
# as the preferred target directly, rather than the cycle-through-order
# _cycle_battle_target below provides -- this is the only way the player can
# actually choose a target when more than one enemy is in range, since
# keyboard shortcuts for battle actions were removed in favor of mouse-only
# menus (see test_battle_mouse_only.gd).
func _on_enemy_target_selected(idx: int) -> void:
	if battle_turn != "player" or idx < 0 or idx >= battle_units.size():
		return
	battle_target_index = idx
	_refresh_battle_display()

# Hover-LOS: no-ops outside Stealth -- every enemy trivially sees the player
# then, so there's nothing meaningful to visualize (see
# _enemy_currently_sees_player). While stealthed, shows the tiles the
# hovered enemy could spot the player from.
# Detection is always on, so this is always meaningful now -- not just
# while stealthed (see ENEMY_SIGHT_RANGE/STEALTH_SIGHT_RANGE).
func _on_enemy_hovered(idx: int) -> void:
	if idx < 0 or idx >= battle_units.size():
		return
	var u: Dictionary = battle_units[idx]
	var sight_range: int = STEALTH_SIGHT_RANGE if player.stealth_turns_remaining > 0 else ENEMY_SIGHT_RANGE
	var tiles: Array = []
	for dx in range(-sight_range, sight_range + 1):
		for dy in range(-sight_range, sight_range + 1):
			if abs(dx) + abs(dy) > sight_range:
				continue
			var tile: Vector2i = u.tile + Vector2i(dx, dy)
			if not _in_battle_bounds(tile):
				continue
			if _has_line_of_sight(u.tile, tile):
				tiles.append(tile)
	hud.show_sight_tiles(tiles)

func _on_enemy_unhovered() -> void:
	hud.hide_sight_tiles()

func _cycle_battle_target(step: int) -> void:
	var targetable := _targetable_indices()
	if targetable.size() <= 1:
		return
	var cur := targetable.find(battle_target_index)
	if cur == -1:
		cur = 0
	else:
		cur = (cur + step + targetable.size()) % targetable.size()
	battle_target_index = targetable[cur]

func _knockback_dir(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff := to - from
	return Vector2i(sign(diff.x), sign(diff.y))

# Shoves a surviving target one tile straight back from the attacker. Rocks
# block the push outright and stun whoever slammed into one; cliffs deal the
# same fall damage anyone else would take crossing one. Orcs are bulky enough
# to sometimes just plant their feet and resist it entirely, and a Boss is
# too heavy to ever be moved at all -- unless bypass_resist forces it through
# (a "guaranteed_knockback" special), which still works on anything.
# extra_distance chains a second push if the first one lands cleanly.
func _apply_knockback(u: Dictionary, dir: Vector2i, bypass_resist: bool = false, extra_distance: bool = false) -> void:
	if not bypass_resist:
		var resist_chance: float = ENEMY_TRAITS.get(u.name, {}).get("knockback_resist", 0.0)
		if resist_chance > 0.0 and randf() < resist_chance:
			hud.battle_log("The %s holds its ground!" % u.name)
			return
	var size: int = u.get("size", 1)
	var steps := 2 if extra_distance else 1
	if size > 1:
		# Terrain-ignoring multi-tile unit -- no rock-stun or cliff-fall,
		# just shove the whole footprint or not.
		for i in steps:
			var big_result := _resolve_big_unit_step(u.tile, size, dir, u.ref)
			if not big_result.moved:
				return
			u.tile = big_result.tile
			hud.battle_log("The %s is knocked back!" % u.name)
		return
	for i in steps:
		var result := _resolve_battle_step(u.tile, dir)
		if not result.moved:
			var blocking_terrain = battle_terrain.get(u.tile + dir, null)
			if blocking_terrain != null and blocking_terrain.type == "rock":
				u["stunned"] = true
				hud.battle_log("The %s is slammed into the rock, stunned!" % u.name)
			elif blocking_terrain != null and blocking_terrain.type == "rubble":
				# Rubble (reserved terrain) is a destructible Rock -- a
				# knockback into it has a chance to crumble it away entirely
				# instead of stunning, opening the tile up for the rest of
				# the fight.
				if randf() < RUBBLE_CRUMBLE_CHANCE:
					battle_terrain.erase(u.tile + dir)
					hud.battle_log("The rubble crumbles away from the impact!")
				else:
					u["stunned"] = true
					hud.battle_log("The %s is slammed into the rubble, stunned!" % u.name)
			return
		u.tile = result.tile
		hud.battle_log("The %s is knocked back!" % u.name)
		if result.fell:
			var dmg := int(round(float(u.max_hp) * CLIFF_FALL_DAMAGE_PCT))
			u.hp -= dmg
			hud.battle_log("The %s tumbles off the edge and takes %d damage!" % [u.name, dmg])
			return

# Applies one hit (damage + effect + knockback) to a single battle_units
# index, removing it from the squad if it dies. Shared by the regular
# attack, heavy attack, and every weapon special.
#
# `weapon` is a snapshot taken once at the start of _battle_perform_attack,
# not a live re-read of player.current_weapon -- a break-chance roll on an
# earlier hit within the same multi-hit action (cleave_all, double_hit, the
# cleave-splash passive) would otherwise swap player.current_weapon to Club
# mid-action, silently changing every later hit's damage/lifesteal/etc. to
# bare-fists stats instead of the weapon actually being swung.
#
# `attacker_tile` defaults to a sentinel (GDScript default params must be
# constants, so this can't default to the instance var battle_player_tile
# directly) -- resolves to the player's own tile when left unset, which
# every existing player-attack call site relies on. _process_ally_turn is
# the one caller that passes its own tile explicitly.
func _apply_single_hit(idx: int, dmg_mult: float, effect: String, weapon: Dictionary, attacker_label: String = "You", attacker_tile: Vector2i = Vector2i(-1, -1), flat_dmg: int = -1) -> void:
	if idx < 0 or idx >= battle_units.size():
		return
	var u = battle_units[idx]
	var dodge_chance: float = ENEMY_TRAITS.get(u.name, {}).get("dodge_chance", 0.0)
	if dodge_chance > 0.0 and randf() < dodge_chance:
		hud.battle_log("The %s dodges out of the way!" % u.name)
		return
	# Blindness: gated on attacker_label the same way shield-vengeance/crit
	# are below, so an ally's own attack funneling through this same function
	# is never affected by the player's own blindness. A miss whiffs entirely
	# (same early-return shape as the dodge check above); anything that isn't
	# a miss is a guaranteed crit instead of the normal Dexterity roll.
	var blind_forced_crit := false
	if attacker_label == "You" and player_blind_turns > 0:
		if randf() < BLINDNESS_MISS_CHANCE:
			hud.battle_log("Blinded, you swing wildly and miss the %s!" % u.name)
			return
		blind_forced_crit = true
	# Stealth: the player's own next attack after going stealthy is a
	# guaranteed crit, breaking stealth immediately (only the first hit of a
	# multi-hit special, since stealth_turns_remaining is consumed right
	# here). was_unaware is resolved from the pre-hit state BEFORE that
	# consumption, so the Dagger sneak-crit bonus below reads the same,
	# correct "did this enemy see me coming" answer regardless of whether
	# this exact hit is what breaks stealth.
	var stealth_forced_crit := false
	var was_unaware := false
	if attacker_label == "You":
		was_unaware = not _enemy_currently_sees_player(u)
		if player.stealth_turns_remaining > 0:
			stealth_forced_crit = true
			player.stealth_turns_remaining = 0
	var dmg: int = int(round(player.attack_damage * weapon.get("damage_mult", 1.0) * dmg_mult))
	# Special arrows deal a flat/semi-flat amount computed by the caller
	# (_battle_player_arrow) instead of the usual weapon-scaled formula --
	# overridden here, before it, rather than after, so the modifiers below
	# (shrine blessing/curse, cover, frozen bonus) still apply on top of it
	# same as they would for any other hit.
	if flat_dmg >= 0:
		dmg = flat_dmg
	# Pichaku (Hand Picks): only touches the plain Attack/Heavy Attack
	# (effect == "" is what distinguishes those two from every named
	# special) -- doesn't stack onto a special's own already-tuned numbers.
	if player.pichaku_active and effect == "":
		dmg = int(round(dmg * PICHAKU_DAMAGE_MULT))
	# Ancient Shrine random event: a temporary blessing/curse on every hit
	# this function resolves, including the Blade Ally's (it's a shared
	# synthetic-weapon call into this same function).
	if player.temp_damage_bonus_pct != 0.0:
		dmg = int(round(dmg * (1.0 + player.temp_damage_bonus_pct)))
	# Adrenaline (repurposed): extra damage DEALT while below 30% HP -- a
	# berserker's edge, not a defensive cushion anymore.
	if player.meta_low_hp_damage_bonus_pct > 0.0 and float(player.health) < float(player.max_health) * 0.3:
		dmg = int(round(dmg * (1.0 + player.meta_low_hp_damage_bonus_pct)))
	# Momentum: stacks per enemy defeated THIS battle (battle_momentum_stacks,
	# reset in _setup_battle_grid, incremented in _on_enemy_died).
	if player.meta_momentum_pct_per_kill > 0.0 and battle_momentum_stacks > 0:
		dmg = int(round(dmg * (1.0 + player.meta_momentum_pct_per_kill * battle_momentum_stacks)))
	# Rage/Berserk: gated on attacker_label the same way every other
	# player-only bonus here is, so an ally's own attack (funneling through
	# this same function) never picks up the player's own berserk state.
	if attacker_label == "You" and player.berserk_turns_remaining > 0:
		dmg = int(round(dmg * (1.0 + BERSERK_DAMAGE_BONUS_PCT + player.meta_rage_bonus_pct)))
	# Brawler's Buckler (shield special "vengeance"): consumed by the
	# player's very next regular/heavy attack after a shield block triggers
	# -- gated on attacker_label so an ally's own attack (which funnels
	# through this same function) can never eat the bonus.
	if player.shield_vengeance_active and effect == "" and attacker_label == "You":
		dmg = int(round(dmg * (1.0 + player.shield_special_pct())))
		player.shield_vengeance_active = false
		hud.battle_log("Your shield's vengeance empowers the blow!")
	# Bloodreaver's passive_execute_bonus behaves like the explicit execute
	# effect but with its own bonus amount -- whichever is bigger wins rather
	# than stacking, so a Mythic Battle Axe's own execute special doesn't
	# double-dip with its own passive.
	var execute_bonus: float = weapon.get("passive_execute_bonus", 0.0)
	if effect == "execute":
		execute_bonus = max(execute_bonus, 0.5)
	if execute_bonus > 0.0 and float(u.hp) < float(u.max_hp) * 0.3:
		dmg = int(round(dmg * (1.0 + execute_bonus)))
	# War Hammer's Maracas: extra damage specifically against an armored
	# target -- the mirror image of Execution's "does nothing without armor."
	if effect == "maracas" and u.get("armored", false):
		dmg = int(round(dmg * MARACAS_ARMORED_MULT))
	# Hand Picks' passive_armor_pierce_pct: the same "extra damage against an
	# armored target" idea as Maracas above, but always-on with any attack
	# instead of gated to one named special.
	var armor_pierce_pct: float = weapon.get("passive_armor_pierce_pct", 0.0)
	if armor_pierce_pct > 0.0 and u.get("armored", false):
		dmg = int(round(dmg * (1.0 + armor_pierce_pct)))
	# Any weapon's passive_ignore_cover (e.g. Starfall) skips the reduction
	# the same way the dedicated ignore_cover special already does. Club's
	# Leg Blow and Spear's Piercing Thrust also ignore cover, on top of their
	# own separate effects.
	# Dexterity: a crit roll for the player's own attacks only (gated on
	# attacker_label the same way shield-vengeance is above, so an ally's
	# attack funneling through this same function never crits off the
	# player's stat) -- doubles damage and ignores the rock-cover reduction
	# below entirely ("ignores defense"), same as Blindness's guaranteed
	# crit-on-hit reuses.
	var is_crit := blind_forced_crit or stealth_forced_crit
	if attacker_label == "You" and not is_crit and player.meta_crit_chance > 0.0 and randf() < player.meta_crit_chance:
		is_crit = true
	if is_crit:
		dmg = int(round(dmg * 2.0))
	var ignores_cover: bool = is_crit or effect in ["ignore_cover", "leg_blow", "piercing_thrust"] or weapon.get("passive_ignore_cover", false)
	if not ignores_cover and _has_adjacent_rock(u.tile):
		dmg = int(round(dmg * (1.0 - ROCK_COVER_REDUCTION)))
	# Frozen (Freeze Arrow): +20% damage taken from every hit while the
	# status is active, on top of whatever else already modified dmg above.
	if u.get("frozen_turns", 0) > 0:
		dmg = int(round(dmg * 1.2))
	# Burn: -25% damage DEALT while it's active, gated on attacker_label the
	# same way shield-vengeance/crit are above so an ally's own attack (which
	# funnels through this same function) is never reduced by the player's
	# own burn.
	if attacker_label == "You" and player_burning:
		dmg = int(round(dmg * (1.0 - BURN_DAMAGE_DEALT_REDUCTION)))
	# Vulnerable: +25% damage taken while active, from ANY attacker (player
	# or ally, since both funnel through this same function) -- "focus this
	# target down" once you've found the opening. Checked before a landed
	# crit below (re)sets it, so the triggering hit itself doesn't
	# retroactively benefit from its own mark.
	if u.get("vulnerable_turns", 0) > 0:
		dmg = int(round(dmg * (1.0 + VULNERABLE_DAMAGE_TAKEN_BONUS_PCT)))
	# Dagger's sneak-crit bonus: a crit landed on an enemy that hadn't
	# noticed the player yet (was_unaware, resolved above before Stealth
	# could be consumed) deals extra flat damage.
	if is_crit and attacker_label == "You" and was_unaware and _player_has_dagger():
		dmg += KNIFE_STEALTH_CRIT_BONUS
	if is_crit:
		u.vulnerable_turns = VULNERABLE_TURNS
	# Getting hit obviously reveals you -- an unaware target is always
	# spotted by whatever just landed on it, player or ally alike.
	u["aware_of_player"] = true
	u.hp -= dmg
	run_damage_dealt += dmg
	play_sfx("hit")
	if is_crit:
		hud.battle_log("Critical hit!")
	hud.battle_log("%s hit the %s for %d damage." % [attacker_label, u.name, dmg])
	var origin_tile: Vector2i = attacker_tile if attacker_tile.x >= 0 else battle_player_tile
	var lunge_color: Color = ATTACK_LUNGE_PLAYER_COLOR if origin_tile == battle_player_tile else ATTACK_LUNGE_ALLY_COLOR
	_spawn_battle_attack_lunge(origin_tile, u.tile, lunge_color, false)
	_spawn_battle_damage_number(u.tile, dmg, u.get("size", 1))
	_flash_battle_tile(u.tile, u.get("size", 1))
	_shake_battle(4.0, 0.15)
	# Gold/Bone/Obsidian-forged weapons carry a break_chance -- a real risk
	# each swing, not just shop flavor text. Club is always owned for free,
	# so try_buy_weapon re-equips it at no cost the same way the shop's
	# "already owned" path does. Only breaks if this hit's weapon is still
	# the one currently equipped -- an earlier hit in this same action may
	# have already broken and swapped it out.
	var break_chance: float = weapon.get("break_chance", 0.0)
	if break_chance > 0.0 and player.current_weapon.get("id", "") == weapon.get("id", "") and randf() < break_chance:
		var broken_name: String = weapon.get("name", "weapon")
		var broken_id: String = weapon.get("id", "")
		player.owned_weapons.erase(broken_id)
		player.try_buy_weapon(WeaponsScript.CLUB)
		hud.battle_log("Your %s shatters! You're back to bare fists." % broken_name)
	if effect == "lifesteal":
		var heal_amt: int = max(1, int(round(dmg * LIFESTEAL_PCT)))
		player.heal(heal_amt)
		hud.battle_log("You drain %d HP from the wound." % heal_amt)
	if effect == "leg_blow" and u.hp > 0:
		u.move_range = max(1, int(u.move_range) - 1)
		hud.battle_log("The %s is hobbled, slowing it down!" % u.name)
	if effect == "low_sweep" and u.hp > 0 and randf() < LOW_SWEEP_CHANCE:
		u.move_range = max(1, int(u.move_range / 2))
		hud.battle_log("The %s is swept off its feet, slowed dramatically!" % u.name)
	if effect == "crushing_collision" and u.hp > 0 and u.get("armored", false):
		u.armored = false
		hud.battle_log("The %s's armor is shattered!" % u.name)
	if effect == "bonk" and u.hp > 0:
		u.concussed_turns = BONK_CONCUSSED_TURNS
		hud.battle_log("The %s is left dazed and concussed!" % u.name)
	if effect == "wrist_strike" and u.hp > 0:
		u.disarmed_tile = _pick_disarm_tile()
		hud.battle_log("The %s's weapon is knocked loose!" % u.name)
	if effect == "arrow_flame" and u.hp > 0:
		u.burning = true
		hud.battle_log("The %s catches fire!" % u.name)
	if effect == "arrow_freeze" and u.hp > 0:
		u.frozen_turns = randi_range(ARROW_FREEZE_MIN_TURNS, ARROW_FREEZE_MAX_TURNS)
		hud.battle_log("The %s freezes solid!" % u.name)
	# Clothesliner: pulls the target to the tile directly behind the player
	# (opposite the direction they were just struck from) instead of the
	# usual push-away knockback -- silently skipped if that tile is out of
	# bounds or already occupied, damage still applies either way.
	if effect == "clotheslined" and u.hp > 0:
		var behind_dir: Vector2i = _knockback_dir(battle_player_tile, u.tile)
		var behind_tile: Vector2i = battle_player_tile - behind_dir
		if _in_battle_bounds(behind_tile) and not _battle_tile_occupied(behind_tile, u.ref):
			u.tile = behind_tile
			hud.battle_log("The %s is hurled behind you!" % u.name)
	# Stormfang's passive_lifesteal_pct (and later, Rune of the Leech) heals
	# on every hit regardless of the chosen action's own effect -- separate
	# from the explicit lifesteal effect above, and stacks with it on
	# purpose if a weapon ever has both.
	var passive_lifesteal_pct: float = weapon.get("passive_lifesteal_pct", 0.0)
	if passive_lifesteal_pct > 0.0 and dmg > 0:
		var passive_heal: int = max(1, int(round(dmg * passive_lifesteal_pct)))
		player.heal(passive_heal)
		hud.battle_log("Your weapon drains %d HP from the wound." % passive_heal)
	if u.hp > 0:
		var dir := _knockback_dir(battle_player_tile, u.tile)
		if effect == "guaranteed_knockback" or weapon.get("passive_guaranteed_knockback", false):
			_apply_knockback(u, dir, true, true)
		elif effect != "whirlwind_strike" and effect != "clotheslined" and not effect.begins_with("arrow_"):
			# Whirlwind Strike re-queries who's targetable before each of its
			# 2-5 passes -- the default knockback below would shove a
			# non-resistant target out of melee range after pass 1, silently
			# turning "several spinning hits" into just one. Clothesliner
			# already repositioned the target itself, above -- the default
			# push-away knockback would immediately override that. Arrows are
			# ammunition, not a physical shove -- no weapon special reads as
			# a knockback here either.
			_apply_knockback(u, dir)
		if effect == "stun_bypass" and u.hp > 0 and is_instance_valid(u.ref):
			u["stunned"] = true
			hud.battle_log("The %s is stunned!" % u.name)
	if u.hp <= 0:
		hud.battle_log("The %s falls!" % u.name)
		_spawn_battle_death_burst(u.tile, u.get("size", 1))
		_shake_battle(8.0, 0.25)
		if is_instance_valid(u.ref):
			u.ref.take_damage(9999)
		battle_units.remove_at(idx)
		if battle_target_index >= battle_units.size():
			battle_target_index = 0

# Shared entry point for the regular attack, heavy attack, and every weapon
# special -- action is {stamina_cost, dmg_mult, effect, name}.
func _battle_perform_attack(action: Dictionary) -> void:
	var cost: int = action.get("stamina_cost", 0)
	if cost > 0 and not player.spend_stamina(cost):
		hud.battle_log("Not enough stamina for %s!" % action.name)
		return
	var effect: String = action.get("effect", "")
	var targetable := _targetable_indices()
	# Hand Picks' DIAMONDS can strike any enemy anywhere on the grid, not
	# just one within normal range -- it checks battle_units directly
	# instead of the range-limited targetable list every other action uses.
	var no_target: bool = battle_units.is_empty() if effect == "diamonds" else targetable.is_empty()
	if no_target:
		hud.battle_log("No enemy in range.")
		if cost > 0:
			player.regen_stamina(cost)
		return

	if tutorial_active and tutorial_step == 1 and action.get("is_regular_attack", false):
		_advance_tutorial_hint()

	# Snapshotted once, not re-read live from player.current_weapon on every
	# _apply_single_hit call -- see that function's comment for why (a break
	# roll partway through a multi-hit action must not change the stats
	# later hits in the SAME action use).
	var weapon: Dictionary = player.current_weapon
	var dmg_mult: float = action.get("dmg_mult", 1.0)

	# Spear's Target Practice is a coin-flip instakill, not a normal
	# damage-dealing hit -- resolved entirely separately from the dmg_mult
	# pipeline every other special/attack below goes through.
	if effect == "target_practice":
		_resolve_target_practice()
	# Greatsword's (new) Wide Cleave -- an area hit on 3 tiles in a line
	# toward the current target, not the targetable-enemies list at all, so
	# it's resolved entirely separately too. Refunds its stamina cost if
	# cover blocks it outright -- the action never actually happened.
	elif effect == "wide_cleave":
		if not _resolve_wide_cleave(weapon, dmg_mult) and cost > 0:
			player.regen_stamina(cost)
	# Battle Axe's Execution: another coin-flip-shaped instakill (this time
	# on the target's armored flag, not a random roll), same reasoning as
	# Target Practice for resolving it outside the dmg_mult pipeline.
	elif effect == "execution":
		_resolve_execution()
	# Hand Picks' Pichaku: a pure self-buff, no damage dealt at all -- it
	# still costs the turn (falls through to _end_player_turn() below like
	# everything else), it just skips the whole dmg_mult pipeline.
	elif effect == "pichaku":
		player.pichaku_active = true
		hud.battle_log("You get in the zone -- lighter, faster strikes for the rest of the fight!")
	# Hand Picks' DIAMONDS: teleport-strike, resolved separately since it
	# targets by grid position rather than the range-limited targetable list.
	elif effect == "diamonds":
		_resolve_diamonds(weapon, dmg_mult)
	elif effect == "ol_one_two":
		# Knuckle Gloves' The 'Ol One-Two: hits the current target twice at
		# full dmg_mult if it's the only one in range, or splits between it
		# and the next-closest enemy at the special's own (lower)
		# split_dmg_mult if a second one is available.
		var primary_idx := _effective_target_index()
		var others: Array = targetable.duplicate()
		others.erase(primary_idx)
		if others.is_empty():
			_apply_single_hit(primary_idx, dmg_mult, effect, weapon)
			if primary_idx < battle_units.size():
				_apply_single_hit(primary_idx, dmg_mult, effect, weapon)
		else:
			var split_mult: float = action.get("split_dmg_mult", dmg_mult)
			others.sort()
			# The secondary's index can shift if the primary hit kills a
			# lower-indexed unit -- captured by reference, re-found after.
			var secondary_ref = battle_units[others[0]].ref
			_apply_single_hit(primary_idx, split_mult, effect, weapon)
			var secondary_idx := -1
			for j in battle_units.size():
				if battle_units[j].ref == secondary_ref:
					secondary_idx = j
					break
			if secondary_idx >= 0:
				_apply_single_hit(secondary_idx, split_mult, effect, weapon)
	elif effect == "cleave_all":
		var targets := targetable.duplicate()
		targets.sort()
		targets.reverse()
		for idx in targets:
			_apply_single_hit(idx, dmg_mult, effect, weapon)
	elif action.has("pass_count_min"):
		# Greatsword's Whirlwind Strike -- several full cleave_all-style
		# passes in a row, re-querying who's still targetable before each
		# pass so a kill mid-flurry doesn't leave a stale index behind.
		var passes: int = randi_range(action.pass_count_min, action.pass_count_max)
		for p in passes:
			var pass_targets := _targetable_indices()
			pass_targets.sort()
			pass_targets.reverse()
			for idx in pass_targets:
				_apply_single_hit(idx, dmg_mult, effect, weapon)
	elif action.has("hit_count_min"):
		# A randomized flurry of hits on one target (Spear's Wombo Combo,
		# Dagger's Flurry Slice, Hand Picks' Minernado) -- stops early if an
		# earlier hit in the flurry already killed the target, same
		# still-primary-target guard the rest of this function uses.
		var idx := _effective_target_index()
		var primary_ref = null
		if idx < battle_units.size():
			primary_ref = battle_units[idx].ref
		var still_primary_target := func() -> bool:
			return idx < battle_units.size() and battle_units[idx].ref == primary_ref
		var hit_count: int = randi_range(action.hit_count_min, action.hit_count_max)
		if action.get("luck_scales_hits", false):
			hit_count += int(floor(player.luck_bonus * 10))
		for i in hit_count:
			if not still_primary_target.call():
				break
			_apply_single_hit(idx, dmg_mult, effect, weapon)
	else:
		var idx := _effective_target_index()
		# Captured by reference (not index) before the hit lands, since a
		# kill shifts every later index down by one via remove_at. Every
		# follow-up hit below (double_hit, double_strike,
		# passive_double_hit_chance) re-checks this reference, not just the
		# index bounds -- otherwise a kill on the first hit would redirect
		# the "second hit" onto whatever unit slides into that slot,
		# possibly one that was never even in range this turn.
		var primary_ref = null
		# Captured before the hit lands too -- Piercing Thrust needs the
		# ORIGINAL target's tile to find who's standing one step further
		# beyond it, and a kill would otherwise remove that information
		# along with the unit itself.
		var primary_tile := Vector2i(-999, -999)
		if idx < battle_units.size():
			primary_ref = battle_units[idx].ref
			primary_tile = battle_units[idx].tile
		var still_primary_target := func() -> bool:
			return idx < battle_units.size() and battle_units[idx].ref == primary_ref
		_apply_single_hit(idx, dmg_mult, effect, weapon)
		if effect == "double_hit" and still_primary_target.call():
			_apply_single_hit(idx, dmg_mult, effect, weapon)
		# Knuckle Gloves' innate double_strike (plain Attack only, not
		# specials -- those already carry their own explicit effect) and any
		# weapon's passive_double_hit_chance (Nightwhisper/Thunderclap).
		if action.get("is_regular_attack", false) and still_primary_target.call():
			if weapon.get("double_strike", false):
				_apply_single_hit(idx, dmg_mult, effect, weapon)
		if still_primary_target.call():
			var double_hit_chance: float = weapon.get("passive_double_hit_chance", 0.0)
			if double_hit_chance > 0.0 and randf() < double_hit_chance:
				_apply_single_hit(idx, dmg_mult, effect, weapon)
		# Pichaku (Hand Picks): while active, every regular/heavy attack gets
		# an independent chance to hit a second time, stacking with any
		# weapon's own passive_double_hit_chance rather than replacing it.
		if effect == "" and player.pichaku_active and still_primary_target.call():
			if randf() < PICHAKU_DOUBLE_HIT_CHANCE:
				_apply_single_hit(idx, dmg_mult, effect, weapon)
		# Duskrender's passive_cleave_pct -- every hit also splashes onto
		# whoever else is targetable, at a reduced fraction of this hit's
		# damage multiplier.
		var cleave_pct: float = weapon.get("passive_cleave_pct", 0.0)
		if cleave_pct > 0.0:
			var splash_targets: Array = _targetable_indices()
			splash_targets.sort()
			splash_targets.reverse()
			for splash_idx in splash_targets:
				if splash_idx < battle_units.size() and battle_units[splash_idx].ref != primary_ref:
					_apply_single_hit(splash_idx, dmg_mult * cleave_pct, effect, weapon)
		# Piercing Thrust: the same hit also lands on whoever's standing one
		# more step beyond the primary target, in the same line -- a
		# diagonal line if the primary was diagonal, since the Spear now
		# targets diagonally too.
		if effect == "piercing_thrust" and primary_tile != Vector2i(-999, -999):
			var pierce_dir: Vector2i = _knockback_dir(battle_player_tile, primary_tile)
			var pierce_tile: Vector2i = primary_tile + pierce_dir
			for j in battle_units.size():
				if battle_units[j].tile == pierce_tile:
					_apply_single_hit(j, dmg_mult, effect, weapon)
					break

	if effect == "self_heal":
		var heal_amt := int(round(player.max_health * SELF_HEAL_PCT))
		player.heal(heal_amt)
		hud.battle_log("You feel invigorated! Healed %d HP." % heal_amt)
	if effect == "knife_throw":
		player.disarmed_tile = _pick_disarm_tile()
		hud.battle_log("The throw leaves you weaponless -- it lands on a random tile!")
	if effect == "devastating_slash":
		battle_player_turns_to_skip += 1
		hud.battle_log("The devastating blow leaves you reeling!")

	# Only the real plain Attack regens stamina this way -- Gravedigger's
	# passive_free_specials also zeroes cost for a special, but a special
	# forced to cost 0 shouldn't ALSO refund stamina like a genuine free hit.
	if action.get("is_regular_attack", false):
		player.regen_stamina(STAMINA_REGEN_ON_ATTACK)

	if battle_units.is_empty():
		_battle_victory()
		return
	_end_player_turn()

# Spear's Target Practice: a straight coin-flip against the current target
# (lower odds vs. a boss), bypassing the normal damage pipeline entirely --
# either the target drops instantly or the attempt whiffs and disarms the
# player. Only called once _battle_perform_attack has already confirmed a
# target is in range.
func _resolve_target_practice() -> void:
	var idx := _effective_target_index()
	var u = battle_units[idx]
	var is_boss: bool = u.name in ["Boss", "Owlbear"]
	var chance: float = TARGET_PRACTICE_BOSS_CHANCE if is_boss else TARGET_PRACTICE_CHANCE
	if randf() < chance:
		hud.battle_log("Target Practice finds its mark -- the %s drops instantly!" % u.name)
		_spawn_battle_attack_lunge(battle_player_tile, u.tile, ATTACK_LUNGE_PLAYER_COLOR, false)
		_spawn_battle_death_burst(u.tile, u.get("size", 1))
		if is_instance_valid(u.ref):
			u.ref.take_damage(9999)
		battle_units.remove_at(idx)
		if battle_target_index >= battle_units.size():
			battle_target_index = 0
	else:
		player.disarmed_tile = _pick_disarm_tile()
		hud.battle_log("Target Practice misses -- your spear flies out of reach!")

# Battle Axe's Execution: instant kill against an armorless target, no
# damage at all against an armored one -- a hard condition on the target's
# "armored" flag rather than a random roll like Target Practice.
func _resolve_execution() -> void:
	var idx := _effective_target_index()
	var u = battle_units[idx]
	if not u.get("armored", false):
		hud.battle_log("Execution finds no armor to stop it -- the %s falls!" % u.name)
		_spawn_battle_attack_lunge(battle_player_tile, u.tile, ATTACK_LUNGE_PLAYER_COLOR, false)
		_spawn_battle_death_burst(u.tile, u.get("size", 1))
		if is_instance_valid(u.ref):
			u.ref.take_damage(9999)
		battle_units.remove_at(idx)
		if battle_target_index >= battle_units.size():
			battle_target_index = 0
	else:
		hud.battle_log("The %s's armor deflects the killing blow!" % u.name)

# Hand Picks' DIAMONDS: teleport-strike onto any enemy on the grid, ignoring
# terrain and normal range entirely -- the caller already confirmed
# battle_units isn't empty before this runs. Doesn't go through
# _effective_target_index()/_targetable_indices() since those are
# range-limited and would reject exactly the far-off targets this special
# exists to reach.
func _resolve_diamonds(weapon: Dictionary, dmg_mult: float) -> void:
	var idx: int = battle_target_index if battle_target_index < battle_units.size() else 0
	var target_tile: Vector2i = battle_units[idx].tile
	_spawn_battle_attack_lunge(battle_player_tile, target_tile, ATTACK_LUNGE_PLAYER_COLOR, false)
	_apply_single_hit(idx, dmg_mult, "diamonds", weapon)
	# The default knockback (see _apply_single_hit) already shoved the target
	# back if it survived -- landing on its PRE-hit tile is what reads as
	# "you jump onto their tile, they get knocked back".
	battle_player_tile = target_tile

func _unit_index_at_tile(t: Vector2i) -> int:
	for i in battle_units.size():
		if battle_units[i].tile == t:
			return i
	return -1

# Greatsword's Wide Cleave: hits whoever's standing in each of the 3 tiles
# directly toward the current target (not a fixed facing -- the tile battle
# has no such concept, so the current target stands in for it, matching
# every other direction-based mechanic here). Refuses outright, no stamina
# spent (see the caller), if cover blocks ANY of the 3 tiles -- unlike the
# normal cover check elsewhere, this is a hard precondition, not a damage
# reduction. Returns false when blocked, true otherwise.
func _resolve_wide_cleave(weapon: Dictionary, dmg_mult: float) -> bool:
	var target_idx := _effective_target_index()
	var dir: Vector2i = _knockback_dir(battle_player_tile, battle_units[target_idx].tile)
	var line_tiles: Array = [battle_player_tile + dir, battle_player_tile + dir * 2, battle_player_tile + dir * 3]
	for t in line_tiles:
		if _has_adjacent_rock(t):
			hud.battle_log("Cover blocks your Wide Cleave!")
			return false
	for t in line_tiles:
		var idx := _unit_index_at_tile(t)
		if idx >= 0:
			_apply_single_hit(idx, dmg_mult, "wide_cleave", weapon)
	return true

func _battle_player_fight() -> void:
	_battle_perform_attack({"stamina_cost": 0, "dmg_mult": 1.0, "effect": "", "name": "Attack", "is_regular_attack": true})

func _battle_player_heavy_attack() -> void:
	_battle_perform_attack({
		"stamina_cost": WeaponsScript.HEAVY_STAMINA_COST,
		"dmg_mult": WeaponsScript.HEAVY_DAMAGE_MULT,
		"effect": "",
		"name": "Heavy Attack",
	})

func _battle_player_special(index: int) -> void:
	var specials: Array = player.current_weapon.get("specials", [])
	if index < 0 or index >= specials.size():
		return
	var action: Dictionary = specials[index]
	# Gravedigger's passive_free_specials -- every special costs 0 stamina.
	if player.current_weapon.get("passive_free_specials", false):
		action = action.duplicate()
		action.stamina_cost = 0
	_battle_perform_attack(action)

# Special arrows: not a weapon special (no stamina cost, no dmg_mult
# pipeline through _battle_perform_attack) -- fired from their own battle
# button, only reachable while the Bow is equipped, consuming 1 of the
# purchased stock instead. Flame/Freeze hit the current single target;
# Bomb ignores targeting entirely and blasts an area (see _resolve_bomb_arrow).
func _battle_player_arrow(kind: String) -> void:
	if player.owned_arrows.get(kind, 0) <= 0:
		hud.battle_log("You're out of %s arrows!" % kind)
		return
	if kind == "bomb":
		var idx := _effective_target_index()
		if idx < 0:
			hud.battle_log("No enemy in range.")
			return
		_resolve_bomb_arrow(battle_units[idx].tile)
	else:
		var idx := _effective_target_index()
		if idx < 0:
			hud.battle_log("No enemy in range.")
			return
		if kind == "flame":
			var flame_dmg: int = ARROW_FLAME_FLAT_DMG + int(round(player.attack_damage * ARROW_FLAME_DMG_STAT_PCT))
			_apply_single_hit(idx, 1.0, "arrow_flame", player.current_weapon, "You", Vector2i(-1, -1), flame_dmg)
		else:
			_apply_single_hit(idx, 1.0, "arrow_freeze", player.current_weapon, "You", Vector2i(-1, -1), ARROW_FREEZE_FLAT_DMG)

	player.owned_arrows[kind] -= 1
	if battle_units.is_empty():
		_battle_victory()
		return
	_end_player_turn()

# True for any tile inside the 3x3 square centered on `center` -- Chebyshev
# distance, not the Manhattan _footprint_dist used elsewhere, so the corners
# of the square count too.
func _in_blast_radius(tile: Vector2i, center: Vector2i, radius: int) -> bool:
	return abs(tile.x - center.x) <= radius and abs(tile.y - center.y) <= radius

# Bomb Arrow: flat damage to every unit in the blast -- enemies, allies, and
# the player alike, matching the description's "can hurt you too" warning.
# Enemies are hit index-descending so a kill mid-blast can't invalidate a
# later index (same convention as cleave_all/Whirlwind Strike).
func _resolve_bomb_arrow(center_tile: Vector2i) -> void:
	var enemy_targets := []
	for i in battle_units.size():
		var hit := false
		for cell in _footprint(battle_units[i].tile, battle_units[i].get("size", 1)):
			if _in_blast_radius(cell, center_tile, ARROW_BOMB_RADIUS):
				hit = true
				break
		if hit:
			enemy_targets.append(i)
	enemy_targets.sort()
	enemy_targets.reverse()
	for idx in enemy_targets:
		_apply_single_hit(idx, 1.0, "arrow_bomb", player.current_weapon, "You", Vector2i(-1, -1), ARROW_BOMB_FLAT_DMG)

	for a in battle_allies:
		if a.hp > 0 and _in_blast_radius(a.tile, center_tile, ARROW_BOMB_RADIUS):
			a.hp -= ARROW_BOMB_FLAT_DMG
			hud.battle_log("Your %s is caught in the blast!" % a.name)
			_spawn_battle_damage_number(a.tile, ARROW_BOMB_FLAT_DMG)

	if _in_blast_radius(battle_player_tile, center_tile, ARROW_BOMB_RADIUS):
		player.take_battle_damage(ARROW_BOMB_FLAT_DMG)
		hud.battle_log("You're caught in your own blast for %d damage!" % ARROW_BOMB_FLAT_DMG)
		_spawn_battle_damage_number(battle_player_tile, ARROW_BOMB_FLAT_DMG)
		_shake_battle(6.0, 0.2)

func _battle_player_item() -> void:
	var healed: int = player.use_healing_item()
	if healed >= 0:
		hud.battle_log("You used an item and healed %d HP." % healed)
		_end_player_turn()
	else:
		hud.battle_log("No items to use!")

func _battle_player_defend() -> void:
	battle_player_defending = true
	player.regen_stamina(STAMINA_REGEN_ON_DEFEND)
	hud.battle_log("You brace for impact.")
	# Resilience (repurposed): heal a flat amount every time you Defend.
	if player.meta_block_heal_amount > 0:
		player.heal(player.meta_block_heal_amount)
	if tutorial_active and tutorial_step == 2:
		_complete_tutorial()
	_end_player_turn()

# Taunt: mechanically identical to Defend (same reduction, same stamina
# regen, same Resilience synergy) plus battle_player_taunting, which forces
# every enemy onto the player next turn regardless of awareness (see
# _process_enemy_turn's target_tile line).
func _battle_player_taunt() -> void:
	battle_player_defending = true
	battle_player_taunting = true
	# A shout draws every ear, not just this turn's -- permanently reveals
	# the player to the whole squad, same as a landed hit does for its own
	# target (see _apply_single_hit).
	for u in battle_units:
		u["aware_of_player"] = true
	player.regen_stamina(STAMINA_REGEN_ON_DEFEND)
	hud.battle_log("You taunt the enemy, daring them to attack!")
	if player.meta_block_heal_amount > 0:
		player.heal(player.meta_block_heal_amount)
	_end_player_turn()

func _battle_player_stealth() -> void:
	if not player.spend_stamina(STEALTH_STAMINA_COST):
		hud.battle_log("Not enough stamina to vanish into the shadows!")
		return
	player.stealth_turns_remaining = STEALTH_TURNS
	hud.battle_log("You slip into the shadows.")
	_end_player_turn()

# Guardian's Ultimatum (Survivor capstone): an emergency heal independent of
# any weapon, gated by a per-battle cooldown instead of stamina.
func _battle_player_skill() -> void:
	if not player.has_guardian_skill or battle_skill_cooldown > 0:
		return
	var heal_amt: int = roundi(player.max_health * 0.4)
	player.heal(heal_amt)
	hud.battle_log("Guardian's Ultimatum! You recover %d HP." % heal_amt)
	battle_skill_cooldown = 4
	_end_player_turn()

func _end_player_turn() -> void:
	if battle_skill_cooldown > 0:
		battle_skill_cooldown -= 1
	# Water pushes whoever's standing on it at the end of a turn -- enemies
	# already got this (see _process_enemy_turn), the player didn't. Heavy
	# Shield's passive makes the player immune to this specifically.
	if not player.shield_push_immune():
		battle_player_tile = _apply_water_push(battle_player_tile)
	_apply_terrain_tick(battle_player_tile)
	_start_ally_turn()

func _start_ally_turn() -> void:
	battle_turn = "ally"
	_refresh_battle_display()
	_process_ally_turn()

# Every recruited companion (party_members, up to max_party_slots, plus the
# separate party_wolf slot that doesn't count against it) now fights as a
# real unit on its own tile: closes distance on whatever the player has
# targeted this battle (falling back to index 0 if that target's already
# dead) via _move_ally_toward, then attacks with the existing
# _apply_single_hit if now in range -- reusing that function's death/loot/
# hit-log handling for the enemy side untouched. Enemies don't move during
# this phase, so the target's tile is stable for the whole loop.
func _process_ally_turn() -> void:
	for u in battle_allies:
		if u.hp <= 0 or battle_units.is_empty():
			continue
		var target_idx: int = battle_target_index if battle_target_index < battle_units.size() else 0
		var target: Dictionary = battle_units[target_idx]
		_move_ally_toward(u, target.tile)
		if u.hp > 0 and _can_battle_attack(u.tile, target.tile, int(u.attack_range)):
			_apply_single_hit(target_idx, u.dmg_mult, "", {"damage_mult": 1.0}, "Your " + u.name, u.tile)
		if u.hp > 0:
			u.tile = _apply_water_push(u.tile, u)

	# Sweep any allies that fell to 0 HP from cliff-fall damage while moving
	# -- deferred to here rather than removed on the spot, matching
	# _process_enemy_turn's own end-of-loop sweep (never mutate battle_allies
	# while still iterating it).
	var ally_i := battle_allies.size() - 1
	while ally_i >= 0:
		if battle_allies[ally_i].hp <= 0:
			hud.battle_log("Your %s is knocked out!" % battle_allies[ally_i].name)
			_spawn_battle_death_burst(battle_allies[ally_i].tile)
			battle_allies.remove_at(ally_i)
		ally_i -= 1

	if battle_units.is_empty():
		_battle_victory()
		return
	_start_enemy_turn()

# Chases an arbitrary target tile (the enemy the player currently has
# targeted), mutating u.tile -- and u.hp on a cliff fall -- in place. Mirrors
# _move_enemy_unit's step-toward-target loop, but is a separate function
# rather than a reuse of it: that one's break condition is hardcoded to
# battle_player_tile specifically (see _pick_enemy_target_tile for how the
# enemy side of this is generalized instead).
func _move_ally_toward(u: Dictionary, target_tile: Vector2i) -> void:
	for i in int(u.move_range):
		if _can_battle_attack(u.tile, target_tile, int(u.attack_range)):
			break
		var dx := 0
		var dy := 0
		if target_tile.x != u.tile.x:
			dx = sign(target_tile.x - u.tile.x)
		if target_tile.y != u.tile.y:
			dy = sign(target_tile.y - u.tile.y)
		var options := []
		if dx != 0:
			options.append(Vector2i(dx, 0))
		if dy != 0:
			options.append(Vector2i(0, dy))
		var stepped := false
		for dir in options:
			var result := _resolve_battle_step(u.tile, dir, u.tile)
			if result.moved:
				u.tile = result.tile
				if result.fell:
					var dmg := int(round(float(u.max_hp) * CLIFF_FALL_DAMAGE_PCT))
					u.hp -= dmg
					hud.battle_log("Your %s falls and takes %d damage!" % [u.name, dmg])
					if u.hp <= 0:
						return
				stepped = true
				break
		if not stepped:
			break

func _start_enemy_turn() -> void:
	battle_turn = "enemy"
	_refresh_battle_display()
	_process_enemy_turn()

# Shared "how much of this incoming hit actually lands" pipeline: Defend,
# rock cover (unless the attacker ignores it), armor, and Fortitude all
# stack the same way regardless of which attack path dealt the damage.
func _apply_incoming_reductions(dmg: int, traits: Dictionary) -> int:
	var reduced := dmg
	if battle_player_defending:
		# Block Master: a chance to no-sell the hit entirely, rolled before
		# Defend's own flat reduction even applies. Rage/Berserk cuts this to
		# a quarter of its normal rate rather than zeroing it outright, same
		# as Reflexes' dodge below.
		var block_negate_chance: float = player.meta_block_negate_chance
		if player.berserk_turns_remaining > 0:
			block_negate_chance *= BERSERK_DEFENSE_MULT
		if block_negate_chance > 0.0 and randf() < block_negate_chance:
			return 0
		reduced = int(round(reduced * (1.0 - DEFEND_DAMAGE_REDUCTION)))
	if not traits.get("ignore_cover", false) and _has_adjacent_rock(battle_player_tile):
		reduced = int(round(reduced * (1.0 - ROCK_COVER_REDUCTION)))
	var total_reduction: float = player.equipped_armor.get("damage_reduction", 0.0) + player.resilience_reduction + player.meta_war_chest_reduction
	# Last Stand: scales continuously with how hurt you are, not a flat
	# below-30% threshold -- every 10% HP missing adds another step.
	if player.meta_last_stand_pct_per_10 > 0.0:
		var missing_pct: float = 1.0 - float(player.health) / float(player.max_health)
		total_reduction += player.meta_last_stand_pct_per_10 * floor(missing_pct * 10.0)
	total_reduction = clampf(total_reduction, 0.0, 0.9)
	reduced = int(round(reduced * (1.0 - total_reduction)))
	return reduced

# A shield's special ability, triggered only when its own passive block roll
# (see _enemy_apply_damage's shield_block_chance() check) actually succeeds --
# the generic "Your shield blocks..." log line is left to that call site,
# this only adds whatever follow-up the specific shield does. attacker is the
# battle_units entry that just swung at the player; raw_dmg is the hit that
# got fully negated (what thorns scales its reflection off of).
func _resolve_shield_block(attacker: Dictionary, raw_dmg: int) -> void:
	var shield: Dictionary = player.equipped_shield
	match shield.get("special", ""):
		"knockback":
			# special_pct is a flag here (see Shields.gd), not a percentage --
			# 0 with an off-synergy weapon (single shove), nonzero with a Spear
			# (extra_distance, a double shove). bypass_resist=true: Heavy
			# Shield's whole point is that this block always lands.
			var extra: bool = player.shield_special_pct() > 0.0
			play_sfx("shield_knockback")
			hud.battle_log("Your shield slams the %s back!" % attacker.name)
			_apply_knockback(attacker, _knockback_dir(battle_player_tile, attacker.tile), true, extra)
		"thorns":
			var idx := _unit_index_at_tile(attacker.tile)
			if idx >= 0:
				var reflected: int = int(round(raw_dmg * player.shield_special_pct()))
				if reflected > 0:
					_apply_single_hit(idx, 1.0, "thorns", player.current_weapon, "Your shield", Vector2i(-1, -1), reflected)
		"vengeance":
			player.shield_vengeance_active = true
			hud.battle_log("Your shield leaves you itching to strike back!")

# Phantom Guard's "evasive": pauses whichever enemy turn just triggered a
# dodge, right at the point of the dodge itself, so the player can walk a few
# free tiles (evasion_steps_left, separate from battle_player_moves_left) and
# then confirm. Driven entirely by _handle_battle's battle_awaiting_evasion
# branch, which reuses the same directional input the Move submenu already
# reads -- see _try_evasion_step below.
#
# This is the only place in the whole turn cycle that awaits mid-resolution.
# It's safe specifically because the await only happens on THIS branch: any
# call to _process_enemy_turn/_enemy_apply_damage that never reaches a dodge
# with Phantom Guard's evasive active runs start-to-finish synchronously,
# exactly as before -- which covers every existing call site (including the
# many tests that call _process_enemy_turn() without awaiting it). Only a
# test that specifically exercises this path needs to await it and drive
# _try_evasion_step/evasion_confirmed itself.
func _prompt_evasion_reposition() -> void:
	evasion_steps_left = player.shield_evasion_steps()
	battle_awaiting_evasion = true
	hud.battle_log("You slip aside! Choose a direction, then Confirm.")
	_refresh_battle_display()
	await evasion_confirmed
	battle_awaiting_evasion = false
	_refresh_battle_display()

# Mirrors _try_battle_player_move, but spends evasion_steps_left instead of
# battle_player_moves_left and doesn't touch battle_move_trail -- there's no
# Cancel/undo for a reactive reposition, just Confirm.
func _try_evasion_step(dir: Vector2i) -> void:
	if evasion_steps_left <= 0:
		return
	var result := _resolve_battle_step(battle_player_tile, dir)
	if not result.moved:
		return
	battle_player_tile = result.tile
	evasion_steps_left -= 1
	_apply_bleed_move_damage()
	if result.fell:
		if player.equipped_armor.get("negates_fall_damage", false):
			hud.battle_log("Your %s lets you shrug off the fall." % player.equipped_armor.name)
		else:
			var dmg := int(round(player.max_health * CLIFF_FALL_DAMAGE_PCT))
			player.take_battle_damage(dmg)
			hud.battle_log("You fall! Took %d damage." % dmg)
	if evasion_steps_left <= 0:
		evasion_confirmed.emit()

# Whichever of {the player, a living ally} sits closest to this enemy right
# now -- ties favor the player. Recomputed fresh every enemy turn rather
# than remembered, matching how the rest of this AI already re-derives
# everything from current tiles each turn instead of caching state.
# Cross-unit target deconfliction: called once per enemy turn, before any
# individual unit acts (see _process_enemy_turn), so a genuine tie between
# two valid targets (the player and a living ally, or two living allies)
# gets split across the enemies threatening it instead of every one of them
# independently converging on whatever _pick_enemy_target_tile alone would
# call nearest. Keyed by u.ref (the enemy Node, same identity anchor this
# file already uses elsewhere -- e.g. "other.ref != u.ref" above) rather than
# the battle_units Dictionary itself, which isn't a stable identity.
# Whenever there's no genuine tie to break -- a single valid target, or one
# that's unambiguously closest -- every unit's assignment collapses back to
# exactly what _pick_enemy_target_tile alone would already give it.
func _assign_enemy_targets() -> Dictionary:
	var ally_tiles: Array = []
	for a in battle_allies:
		ally_tiles.append(a.tile)
	var committed := {}
	for t in ally_tiles:
		committed[t] = 0
	committed[battle_player_tile] = 0
	var assigned := {}
	for u in battle_units:
		if not is_instance_valid(u.ref):
			continue
		# The player is only ever a candidate for a unit that currently sees
		# them (see _enemy_currently_sees_player -- while Stealth is active,
		# this can differ per unit; outside Stealth it's always true, so this
		# reduces to exactly the prior always-include-the-player behavior).
		var targets: Array = ally_tiles.duplicate()
		if _enemy_currently_sees_player(u):
			targets.append(battle_player_tile)
		if targets.is_empty():
			continue
		var footprint: Array = _footprint(u.tile, u.get("size", 1))
		var dists := []
		for t in targets:
			dists.append({"tile": t, "dist": _footprint_dist(footprint, t)})
		dists.sort_custom(func(a, b): return a.dist < b.dist)
		var min_dist: int = dists[0].dist
		var close_candidates := []
		for d in dists:
			if d.dist <= min_dist + TARGET_DECONFLICT_TOLERANCE:
				close_candidates.append(d.tile)
		var chosen: Vector2i = close_candidates[0]
		if close_candidates.size() > 1:
			var best_commit: int = committed[chosen]
			for t in close_candidates:
				if committed[t] < best_commit:
					best_commit = committed[t]
					chosen = t
		committed[chosen] += 1
		assigned[u.ref] = chosen
	return assigned

# Fallback for whatever _assign_enemy_targets didn't assign -- mirrors its
# same awareness gate on the player. Returns Vector2i(-1, -1) ("nothing to
# target -- wander") when the unit doesn't currently see the player and no
# ally exists either, consumed by _process_enemy_turn right after this is
# called.
func _pick_enemy_target_tile(u: Dictionary) -> Vector2i:
	var footprint: Array = _footprint(u.tile, u.get("size", 1))
	var sees_player: bool = _enemy_currently_sees_player(u)
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_dist: int = -1
	if sees_player:
		best_tile = battle_player_tile
		best_dist = _footprint_dist(footprint, battle_player_tile)
	for a in battle_allies:
		var d: int = _footprint_dist(footprint, a.tile)
		if best_dist < 0 or d < best_dist:
			best_dist = d
			best_tile = a.tile
	return best_tile

# Shared "deal damage to whoever this enemy is currently attacking" step.
# Branches between the player (the existing _apply_incoming_reductions
# pipeline: Defend, rock cover, armor, Fortitude) and an ally (rock cover
# only -- Defend/armor/Fortitude are player-only systems, allies have no
# equivalent). Returns {dmg, is_player, target_name} rather than logging
# itself, since the jab/regular-hit call sites in _process_enemy_turn use
# different message wording.
func _enemy_apply_damage(u: Dictionary, target_tile: Vector2i, raw_dmg: int, traits: Dictionary) -> Dictionary:
	if u.get("burning", false):
		raw_dmg = int(round(raw_dmg * (1.0 - BURN_DAMAGE_DEALT_REDUCTION)))
	if target_tile == battle_player_tile:
		# Precision (Warrior wing): a flat chance to fully avoid the hit,
		# mirroring an enemy's own dodge_chance trait but for the player.
		# Rage/Berserk cuts this to a quarter of its normal rate.
		var dodge_chance: float = player.meta_dodge_chance
		if player.berserk_turns_remaining > 0:
			dodge_chance *= BERSERK_DEFENSE_MULT
		if dodge_chance > 0.0 and randf() < dodge_chance:
			# Riposte: a dodge has a further chance to immediately counter
			# whoever swung at you. Found by tile rather than array identity
			# since u is the exact same Dictionary reference battle_units
			# holds, but _unit_index_at_tile is the established, already-
			# proven lookup this codebase uses everywhere else.
			if player.meta_riposte_chance > 0.0 and randf() < player.meta_riposte_chance:
				var attacker_idx := _unit_index_at_tile(u.tile)
				if attacker_idx >= 0:
					hud.battle_log("You riposte!")
					_apply_single_hit(attacker_idx, RIPOSTE_DAMAGE_PCT, "riposte", player.current_weapon)
			# Phantom Guard's "evasive": ANY dodge (not just one its own bonus
			# caused) pauses the attacker's turn right here so the player can
			# pick a nearby tile to relocate to before it resumes. This is the
			# one place in the whole turn cycle that awaits mid-resolution --
			# see _prompt_evasion_reposition's doc comment for why that's safe.
			if player.shield_evasion_active():
				await _prompt_evasion_reposition()
			# Bleeding: a successful dodge costs HP too -- the same wound that
			# makes standing still risky makes flinging yourself aside worse.
			if player_bleeding:
				var dodge_bleed_dmg: int = max(1, int(round(player.max_health * BLEED_DODGE_DAMAGE_PCT)))
				player.take_battle_damage(dodge_bleed_dmg)
				hud.battle_log("The dodge tears your wound further! Lost %d HP." % dodge_bleed_dmg)
			return {"dmg": 0, "is_player": true, "target_name": "", "dodged": true}
		# Shield block: a passive, always-on chance (not gated on Defending,
		# unlike Block Master) to no-sell the hit entirely. Independent roll
		# from the dodge above -- both can be carried at once.
		var block_chance: float = player.shield_block_chance()
		if block_chance > 0.0 and randf() < block_chance:
			play_sfx("shield_block")
			_resolve_shield_block(u, raw_dmg)
			return {"dmg": 0, "is_player": true, "target_name": "", "blocked": true}
		var dmg: int = _apply_incoming_reductions(raw_dmg, traits)
		player.take_battle_damage(dmg)
		run_damage_taken += dmg
		_spawn_battle_attack_lunge(u.tile, target_tile, ATTACK_LUNGE_ENEMY_COLOR, traits.get("attack_range", 1) > 1)
		_spawn_battle_damage_number(target_tile, dmg)
		_flash_battle_tile(target_tile)
		_shake_battle(5.0, 0.2)
		# Concussion (blunt-wielding enemies): a chance to daze the player on
		# any landed hit, same shape as BONK's own self-hit roll but rolled
		# against the player's timer (player_concussed_turns) instead.
		if traits.get("inflicts_concussion", false) and randf() < CONCUSSION_INFLICT_CHANCE:
			player_concussed_turns = PLAYER_CONCUSSION_TURNS
			hud.battle_log("The blow leaves you dazed!")
		# Bleeding (sharp-wielding enemies): guaranteed on a landed hit, no
		# roll -- persists for the rest of the battle (see BLEED_MOVE_DAMAGE_PCT/
		# BLEED_DODGE_DAMAGE_PCT, ticked from movement/dodges, not here).
		if traits.get("inflicts_bleed", false) and not player_bleeding:
			player_bleeding = true
			hud.battle_log("The wound leaves you bleeding!")
		# Blindness (mage-type enemies): guaranteed on a landed hit, refreshes
		# the full duration even if already active.
		if traits.get("inflicts_blind", false):
			player_blind_turns = BLINDNESS_TURNS
			hud.battle_log("Your vision swims -- you're blinded!")
		return {"dmg": dmg, "is_player": true, "target_name": "", "dodged": false}
	var dmg: int = raw_dmg
	if not traits.get("ignore_cover", false) and _has_adjacent_rock(target_tile):
		dmg = int(round(dmg * (1.0 - ROCK_COVER_REDUCTION)))
	var target_name := ""
	for a in battle_allies:
		if a.tile == target_tile:
			a.hp -= dmg
			target_name = a.name
			break
	_spawn_battle_attack_lunge(u.tile, target_tile, ATTACK_LUNGE_ENEMY_COLOR, traits.get("attack_range", 1) > 1)
	_spawn_battle_damage_number(target_tile, dmg)
	_flash_battle_tile(target_tile)
	_shake_battle(5.0, 0.2)
	return {"dmg": dmg, "is_player": false, "target_name": target_name, "dodged": false}

# Every currently-occupied tile (the player, and/or any living ally) within
# this unit's attack_range of its own footprint -- used by the "sweeps"
# trait (the Owlbear) so one swing can catch more than just its chosen
# target. _pick_enemy_target_tile already guarantees at least target_tile
# itself is in range whenever this is called, so the result is never empty.
func _sweep_targets(u: Dictionary) -> Array:
	var footprint: Array = _footprint(u.tile, u.get("size", 1))
	var attack_range: int = u.get("attack_range", 1)
	var targets := []
	if _footprint_dist(footprint, battle_player_tile) <= attack_range:
		targets.append(battle_player_tile)
	for a in battle_allies:
		if _footprint_dist(footprint, a.tile) <= attack_range:
			targets.append(a.tile)
	return targets

func _process_enemy_turn() -> void:
	# Fae Huts queue a spawn here instead of appending to battle_units
	# directly -- mutating the array while this exact loop is still
	# iterating over it would be unsafe, same reason dead units are only
	# ever removed after the loop (see the sweep below). Processed once,
	# after the loop, near that same sweep.
	var fae_spawns_needed: Array = []
	# Freshly latch anyone newly in range/LOS before targets are assigned,
	# so a unit that closed the distance over its own last move is spotted
	# THIS turn's targeting rather than one turn late.
	_update_enemy_awareness()
	var assigned_targets: Dictionary = _assign_enemy_targets()
	for u in battle_units:
		if not is_instance_valid(u.ref):
			continue

		# Burning ticks at the top of every turn regardless of anything else
		# below -- unlike every other status here it has no turn counter, it
		# persists until the unit steps onto a water tile (_apply_water_push).
		if u.get("burning", false):
			var burn_dmg: int = max(1, int(round(float(u.max_hp) / BURN_DAMAGE_DIVISOR)))
			u.hp -= burn_dmg
			_spawn_battle_damage_number(u.tile, burn_dmg, u.get("size", 1))
			hud.battle_log("The %s burns for %d damage!" % [u.name, burn_dmg])
			if u.hp <= 0:
				continue

		# Poison Bog's lingering DOT (reserved terrain) -- same "ticks
		# regardless, doesn't skip a turn" shape as burning, just its own
		# separate counter so the two hazards don't overwrite each other.
		if u.get("poison_turns", 0) > 0:
			u.poison_turns -= 1
			u.hp -= u.poison_dmg
			_spawn_battle_damage_number(u.tile, u.poison_dmg, u.get("size", 1))
			hud.battle_log("The %s is poisoned for %d damage!" % [u.name, u.poison_dmg])
			if u.hp <= 0:
				continue

		if u.get("frozen_turns", 0) > 0:
			u.frozen_turns -= 1
			hud.battle_log("The %s is frozen solid and can't act!" % u.name)
			u.tile = _apply_water_push(u.tile, u)
			continue

		if u.get("disarmed_tile", Vector2i(-1, -1)) != Vector2i(-1, -1):
			if u.tile == u.disarmed_tile:
				u.disarmed_tile = Vector2i(-1, -1)
			else:
				# attack_range 0 for the 1x1 path means _can_battle_attack
				# never stops the walk early -- it just closes the full
				# distance onto the tile itself, since there's nothing to
				# attack while disarmed anyway.
				if u.get("size", 1) > 1:
					_move_big_unit(u, u.disarmed_tile, u.disarmed_tile)
				else:
					_move_enemy_unit(u, 0, u.disarmed_tile, u.disarmed_tile, false)
				u.tile = _apply_water_push(u.tile, u)
				continue

		# Whether this turn's attack (if any) redirects onto the concussed
		# unit itself -- rolled once per turn and consumed wherever the
		# attack actually resolves below, so pathing/cornering logic (which
		# reads target_tile long before the attack fires) is never affected.
		var self_hit_this_turn := false
		if u.get("concussed_turns", 0) > 0:
			u.concussed_turns -= 1
			self_hit_this_turn = randf() < 0.33

		# Vulnerable: ticks down on the unit's own turn, same shape as
		# Concussion above. The +25% damage-taken multiplier itself lives in
		# _apply_single_hit.
		if u.get("vulnerable_turns", 0) > 0:
			u.vulnerable_turns -= 1

		if u.get("stunned", false):
			u["stunned"] = false
			hud.battle_log("The %s is stunned and can't act!" % u.name)
			u.tile = _apply_water_push(u.tile, u)
			continue

		var traits: Dictionary = ENEMY_TRAITS.get(u.name, {})
		var size: int = u.get("size", 1)
		var attack_range: int = u.get("attack_range", 1)
		var ignore_line: bool = traits.get("ignore_line", false)

		if traits.get("heals_allies", false):
			var has_other_allies := false
			for other in battle_units:
				if other.ref != u.ref:
					has_other_allies = true
					break
			if has_other_allies:
				# Refuses to engage at all while anyone else is still up --
				# heals if it can, otherwise (Druid only) buffs an ally
				# instead, otherwise just watches and waits.
				if not _try_heal_ally(u):
					if not (traits.get("buffs_allies", false) and _try_buff_ally(u)):
						hud.battle_log("The %s hangs back, waiting for an opening." % u.name)
				u.tile = _apply_water_push(u.tile, u)
				continue
			# Last one standing -- falls through to a normal move+attack.

		# Fae Hut: never moves or attacks (see FaeHut.gd's 0 CONTACT_DAMAGE)
		# -- every one of its own turns just counts down to its next spawn.
		if traits.get("spawns_fae", false):
			u.turns_since_spawn = u.get("turns_since_spawn", 0) + 1
			if u.turns_since_spawn >= FAE_HUT_SPAWN_INTERVAL:
				u.turns_since_spawn = 0
				fae_spawns_needed.append(u.tile)
			continue

		# Whichever of {the player, a living ally} this enemy is assigned to
		# threaten this turn -- nearest by default, but see
		# _assign_enemy_targets for how a genuine tie gets split across
		# multiple enemies instead of everyone piling onto the same target.
		# Recomputed fresh every turn rather than remembered, same as the
		# rest of this function's state.
		var target_tile: Vector2i = assigned_targets.get(u.ref, _pick_enemy_target_tile(u))
		# Taunt draws every enemy's attention regardless of awareness --
		# shouting to be noticed bypasses Stealth entirely.
		if battle_player_taunting:
			target_tile = battle_player_tile

		if target_tile == Vector2i(-1, -1):
			# Unaware, nothing to target (see _pick_enemy_target_tile) --
			# amble around instead of standing idle.
			_move_enemy_wander(u)
			u.tile = _apply_water_push(u.tile, u)
			continue

		var was_cornered: bool = traits.get("kites", false) and _can_battle_attack(u.tile, target_tile, 1, ignore_line)
		if was_cornered:
			# The current target has closed to melee range -- back off before
			# doing anything else, trading a step of distance to keep sniping.
			var away_dir := _knockback_dir(target_tile, u.tile)
			var retreat := _resolve_battle_step(u.tile, away_dir)
			if retreat.moved:
				u.tile = retreat.tile
				if retreat.fell:
					var fall_dmg := int(round(float(u.max_hp) * CLIFF_FALL_DAMAGE_PCT))
					u.hp -= fall_dmg
					hud.battle_log("The %s falls and takes %d damage!" % [u.name, fall_dmg])
					if u.hp <= 0:
						continue
				hud.battle_log("The %s backs away to keep its distance!" % u.name)

		if not was_cornered and traits.get("strafes", false) and _can_battle_attack(u.tile, target_tile, attack_range, ignore_line) and not _can_battle_attack(u.tile, target_tile, 1, ignore_line):
			# Already lined up for a shot and safe -- shuffle sideways
			# instead of standing still between shots. Breaks its firing
			# line for this turn; the chase logic below realigns it after.
			var diff: Vector2i = target_tile - u.tile
			var perp_dir := Vector2i.ZERO
			if diff.x == 0:
				perp_dir = Vector2i(1 if u.get("strafe_flip", false) else -1, 0)
			elif diff.y == 0:
				perp_dir = Vector2i(0, 1 if u.get("strafe_flip", false) else -1)
			if perp_dir != Vector2i.ZERO:
				var strafe_result := _resolve_battle_step(u.tile, perp_dir)
				if strafe_result.moved:
					u.tile = strafe_result.tile
					hud.battle_log("The %s strafes to the side!" % u.name)
					u.tile = _apply_water_push(u.tile, u)
					continue
				else:
					u["strafe_flip"] = not u.get("strafe_flip", false)

		# A flank tile is a diagonal step past the current target, so it's
		# never actually within melee attack_range once reached -- aim for it
		# only until it's reached, then fall back to closing the remaining
		# distance straight at the target. Without this, a unit that arrives
		# at its own flank tile has nowhere left to go (movement_target ==
		# its own tile gives it zero step options) and goes permanently idle
		# every turn after, forever out of range of an attack it can never
		# line up. Applies regardless of size -- the Owlbear (2x2) corners
		# the same way the Orc (1x1) already does.
		var movement_target: Vector2i = target_tile
		if traits.get("corners", false):
			var flank_tile := _flank_target_tile(target_tile)
			if u.tile != flank_tile:
				movement_target = flank_tile

		# Formation holding: a ranged attacker (ignore_line) that isn't
		# already in range of its target doesn't push forward past a melee
		# ally that's already closer to that target -- it holds position and
		# waits instead of closing the distance itself. heals_allies/
		# buffs_allies units never reach this point while any ally is alive
		# (see the "hangs back" branch above, near the top of this loop), so
		# formation holding only ever matters for the ignore_line kind.
		var holds_formation := false
		if ignore_line:
			var pre_move_can_attack: bool
			if size > 1:
				pre_move_can_attack = _footprint_dist(_footprint(u.tile, size), target_tile) <= attack_range
			else:
				pre_move_can_attack = _can_battle_attack(u.tile, target_tile, attack_range, ignore_line)
			if not pre_move_can_attack:
				var my_dist: int = _footprint_dist(_footprint(u.tile, size), target_tile)
				for other in battle_units:
					if other.ref == u.ref or not is_instance_valid(other.ref):
						continue
					if ENEMY_TRAITS.get(other.name, {}).get("ignore_line", false):
						continue
					var other_dist: int = _footprint_dist(_footprint(other.tile, other.get("size", 1)), target_tile)
					if other_dist < my_dist:
						holds_formation = true
						break
			if holds_formation:
				hud.battle_log("The %s holds position behind its ally!" % u.name)

		if size > 1:
			if not holds_formation:
				_move_big_unit(u, movement_target, target_tile)
		else:
			if not holds_formation:
				_move_enemy_unit(u, attack_range, movement_target, target_tile, ignore_line)

		if u.hp <= 0:
			continue

		var can_attack: bool
		if size > 1:
			can_attack = _footprint_dist(_footprint(u.tile, size), target_tile) <= attack_range
		else:
			can_attack = _can_battle_attack(u.tile, target_tile, attack_range, ignore_line)

		if can_attack and self_hit_this_turn:
			# Concussed (Hammer's BONK): the attack goes wrong and lands on
			# the attacker instead -- a simple, distinct outcome that
			# bypasses windup/quick-jab/sweep entirely rather than trying to
			# redirect each of those independently.
			var self_dmg: int = u.damage
			u.hp -= self_dmg
			_spawn_battle_damage_number(u.tile, self_dmg, u.get("size", 1))
			_flash_battle_tile(u.tile, u.get("size", 1))
			hud.battle_log("The %s, concussed, strikes itself for %d damage!" % [u.name, self_dmg])
			u["winding_up"] = false
		elif can_attack:
			var already_winding_up: bool = u.get("winding_up", false)
			var has_windup: bool = traits.get("windup", false)
			var quick_jab_chance: float = traits.get("quick_jab_chance", 0.0)
			if has_windup and not already_winding_up and quick_jab_chance > 0.0 and randf() < quick_jab_chance:
				# A quick, un-telegraphed jab instead of winding up this time.
				var jab_result: Dictionary = await _enemy_apply_damage(u, target_tile, u.damage, traits)
				if jab_result.get("dodged", false):
					hud.battle_log("You dodge the %s's jab!" % u.name)
				elif jab_result.get("blocked", false):
					hud.battle_log("Your shield blocks the %s's jab!" % u.name)
				elif jab_result.is_player:
					hud.battle_log("The %s jabs you for %d damage!" % [u.name, jab_result.dmg])
					if player.health <= 0:
						return
				else:
					hud.battle_log("The %s jabs your %s for %d damage!" % [u.name, jab_result.target_name, jab_result.dmg])
			elif has_windup and not already_winding_up:
				u["winding_up"] = true
				hud.battle_log("The %s winds up a heavy attack!" % u.name)
			else:
				var dmg: int = u.damage
				if already_winding_up:
					dmg = int(round(dmg * ORC_WINDUP_DAMAGE_MULT))
				u["winding_up"] = false
				var pack_bonus_mult: float = traits.get("pack_bonus_mult", 1.0)
				if pack_bonus_mult > 1.0:
					var has_packmate := false
					for other in battle_units:
						if other.ref != u.ref and other.name == u.name:
							has_packmate = true
							break
					if has_packmate:
						dmg = int(round(dmg * pack_bonus_mult))
						hud.battle_log("The %s fights fiercely alongside its pack!" % u.name)
				# Gnome: unlike Goblin's binary pack_bonus_mult, this counts
				# how many packmates are ALIVE RIGHT NOW (not a one-time
				# snapshot like their HP bonus in _setup_battle_grid) --
				# thinning the mob down visibly softens the survivors' punch,
				# turn by turn, rather than just removing bodies.
				if u.name == "Gnome":
					var live_pack_count := 0
					for other in battle_units:
						if other.name == "Gnome":
							live_pack_count += 1
					if live_pack_count > 1:
						dmg = int(round(dmg * (1.0 + GNOME_DAMAGE_PCT_PER_PACKMATE * (live_pack_count - 1))))
						hud.battle_log("The Gnome mob swarms with %d strong!" % live_pack_count)
				# Druid's buff (see buffed_dmg_turns) -- decremented here, at
				# the moment it actually pays off, same "consumed on use"
				# shape Adrenaline/Momentum-style bonuses use elsewhere.
				if u.get("buffed_dmg_turns", 0) > 0:
					dmg = int(round(dmg * (1.0 + u.get("buffed_dmg_pct", 0.0))))
					u.buffed_dmg_turns -= 1
				var enrage_threshold: float = traits.get("enrage_threshold", 0.0)
				if enrage_threshold > 0.0 and float(u.hp) < float(u.max_hp) * enrage_threshold:
					dmg = int(round(dmg * traits.get("enrage_mult", 1.0)))
					hud.battle_log("The %s is enraged!" % u.name)
				# The Owlbear's sweep hits every occupied tile within range,
				# not just its chosen target -- dmg is computed once above and
				# applied in full to each tile struck, not divided. Every
				# other enemy's sweep_targets is just [target_tile], so this
				# loop is a no-op wrapper for them (identical single hit,
				# identical single log line, as before).
				var sweep_targets: Array = _sweep_targets(u) if traits.get("sweeps", false) else [target_tile]
				var player_was_hit := false
				for t in sweep_targets:
					var hit_result: Dictionary = await _enemy_apply_damage(u, t, dmg, traits)
					if hit_result.get("dodged", false):
						hud.battle_log("You dodge the %s's attack!" % u.name)
					elif hit_result.get("blocked", false):
						hud.battle_log("Your shield blocks the %s's attack!" % u.name)
					elif hit_result.is_player:
						player_was_hit = true
						hud.battle_log("The %s hits you for %d damage." % [u.name, hit_result.dmg])
					else:
						hud.battle_log("The %s hits your %s for %d damage!" % [u.name, hit_result.target_name, hit_result.dmg])
				if player_was_hit and player.health <= 0:
					return
		else:
			# Lost track of its target -- the telegraph doesn't carry over.
			u["winding_up"] = false
		if size == 1:
			u.tile = _apply_water_push(u.tile, u)
			_apply_terrain_tick(u.tile, u)

	# Sweep anyone who died mid-turn from self-inflicted cliff-fall damage
	# (kiting retreat, chasing a target) -- deferred to here rather than
	# removed on the spot so the loop above never mutates battle_units while
	# it's still iterating over it.
	var i := battle_units.size() - 1
	while i >= 0:
		if battle_units[i].hp <= 0:
			hud.battle_log("The %s falls!" % battle_units[i].name)
			_spawn_battle_death_burst(battle_units[i].tile, battle_units[i].get("size", 1))
			if is_instance_valid(battle_units[i].ref):
				battle_units[i].ref.take_damage(9999)
			battle_units.remove_at(i)
		i -= 1
	if battle_target_index >= battle_units.size():
		battle_target_index = 0

	# Fae Hut spawns, queued during the loop above (see fae_spawns_needed) --
	# the ONE place a real unit ever gets added to battle_units mid-battle,
	# rather than only at the initial _setup_battle_grid squad placement.
	for hut_tile in fae_spawns_needed:
		var spawn_tile := _find_empty_tile_near(hut_tile)
		if spawn_tile == Vector2i(-1, -1):
			hud.battle_log("The Fae Hut hums, but there's nowhere for a new Fae to land!")
			continue
		var fae = FaeScript.new()
		fae.died.connect(_on_enemy_died.bind(fae.get_display_name()))
		add_child(fae)
		enemies_alive += 1
		var fae_traits: Dictionary = ENEMY_TRAITS.get("Fae", {})
		battle_units.append({
			"ref": fae, "tile": spawn_tile, "hp": fae.MAX_HEALTH, "max_hp": fae.MAX_HEALTH,
			"move_range": fae_traits.get("move_range", 2), "damage": fae.get_contact_damage(),
			"name": "Fae", "winding_up": false, "stunned": false, "size": 1,
			"attack_range": fae_traits.get("attack_range", 1), "is_elite": false,
			"concussed_turns": 0, "frozen_turns": 0, "burning": false,
			"vulnerable_turns": 0, "aware_of_player": false,
			"armored": false, "disarmed_tile": Vector2i(-1, -1),
		})
		play_sfx("fae_spawn")
		hud.battle_log("The Fae Hut summons a Fae!")

	# Same sweep for any ally an enemy just knocked out (cliff falls handled
	# above via the retreat step; a direct hit is applied in
	# _enemy_apply_damage, above).
	var ally_i := battle_allies.size() - 1
	while ally_i >= 0:
		if battle_allies[ally_i].hp <= 0:
			hud.battle_log("Your %s is knocked out!" % battle_allies[ally_i].name)
			_spawn_battle_death_burst(battle_allies[ally_i].tile)
			battle_allies.remove_at(ally_i)
		ally_i -= 1

	if battle_units.is_empty():
		_battle_victory()
		return

	if not in_battle:
		return

	# Poison Bog's lingering DOT (reserved terrain) -- ticks every round
	# regardless of battle_player_turns_to_skip below, same "doesn't skip a
	# turn on its own" shape as the enemy-side burning/poison ticks.
	if player_poison_turns > 0:
		player_poison_turns -= 1
		player.take_battle_damage(player_poison_dmg)
		hud.battle_log("You're poisoned for %d damage!" % player_poison_dmg)
		if player.health <= 0:
			return

	# Burn: no turn counter, ticks every round it's active until the player
	# steps onto a water tile (cleared in _apply_water_push).
	if player_burning:
		var player_burn_dmg: int = max(1, int(round(float(player.max_health) / BURN_DAMAGE_DIVISOR)))
		player.take_battle_damage(player_burn_dmg)
		hud.battle_log("You burn for %d damage!" % player_burn_dmg)
		if player.health <= 0:
			return

	# Concussion: rolled fresh each turn it's active (PLAYER_CONCUSSION_CHANCE)
	# rather than a guaranteed hit like poison/burn -- mirrors BONK's own
	# 33%-chance self-hit shape but on the player's own timer/turn instead of
	# an enemy's.
	if player_concussed_turns > 0:
		player_concussed_turns -= 1
		if randf() < PLAYER_CONCUSSION_CHANCE:
			var concussion_dmg: int = player.stat_might
			player.take_battle_damage(concussion_dmg)
			hud.battle_log("You're concussed and stumble, taking %d damage!" % concussion_dmg)
			if player.health <= 0:
				return

	# Blindness: ticks down alongside Concussion, same "still active for the
	# turn it reaches 0 on" shape -- consulted below (forced-attack case) and
	# in _apply_single_hit (miss roll/guaranteed crit) whenever the player
	# throws a punch while it's > 0.
	if player_blind_turns > 0:
		player_blind_turns -= 1

	# Rage/Berserk: ticks down the same way, refreshed back to BERSERK_TURNS
	# by _on_enemy_died on any kill mid-battle.
	if player.berserk_turns_remaining > 0:
		player.berserk_turns_remaining -= 1

	# Stealth: ticks down the same way, set to STEALTH_TURNS by
	# _battle_player_stealth (or consumed early, to 0, by the forced crit in
	# _apply_single_hit).
	if player.stealth_turns_remaining > 0:
		player.stealth_turns_remaining -= 1

	if battle_player_turns_to_skip > 0:
		battle_player_turns_to_skip -= 1
		hud.battle_log("You're reeling and can't act this turn!")
		_start_ally_turn()
		return

	battle_turn = "player"
	battle_menu_state = "main"
	battle_move_trail = []
	battle_player_defending = false
	battle_player_taunting = false
	battle_player_moves_left = _battle_player_move_range()
	# Second Breath: passive Stamina regen at the start of every player
	# turn, regardless of what the previous turn's action was.
	if player.meta_stamina_regen_per_turn > 0:
		player.regen_stamina(player.meta_stamina_regen_per_turn)
	_check_disarm_reclaimed()

	# Fear: re-derived fresh every turn (not a stored duration) from whichever
	# inflicts_fear enemy currently has the player within ITS OWN attack
	# range -- an enemy dying or drifting out of range frees the player up
	# immediately rather than a turn late. Per the user's strict answer, this
	# replaces the entire menu: Move/Item/Defend/Skill/Arrow/Flee are all
	# unavailable, only an Attack on the feared enemy happens. Capped by
	# FEAR_CASCADE_LIMIT -- see battle_fear_cascade_depth's doc comment for
	# why an uncapped version of this can hang/crash the game outright.
	battle_feared_by_index = _find_fear_target()
	if battle_feared_by_index >= 0 and battle_fear_cascade_depth < FEAR_CASCADE_LIMIT:
		battle_fear_cascade_depth += 1
		_resolve_feared_turn(battle_feared_by_index)
		return

	battle_fear_cascade_depth = 0
	_focus_battle_main_menu()
	_refresh_battle_display()

# The enemy whose own attack range currently reaches the player, among any
# with ENEMY_TRAITS["inflicts_fear"] -- mirrors _sweep_targets' footprint/
# range-distance shape. -1 if none qualify.
func _find_fear_target() -> int:
	for i in battle_units.size():
		var u: Dictionary = battle_units[i]
		if not ENEMY_TRAITS.get(u.name, {}).get("inflicts_fear", false):
			continue
		var footprint: Array = _footprint(u.tile, u.get("size", 1))
		if _footprint_dist(footprint, battle_player_tile) <= u.get("attack_range", 1):
			return i
	return -1

# Forces the player's entire turn onto a single Attack against the feared
# enemy -- reuses _battle_player_fight's own pipeline (stamina, weapon
# specials, animations) by pointing battle_target_index at it, same as a
# manually clicked target would. If the player's own weapon can't actually
# reach that enemy (Fear only checks the ENEMY's range, not the player's),
# the attack lands on nothing and the turn is still spent being too
# terrified to do anything else -- _end_player_turn is called directly since
# _battle_perform_attack's own "no target" path doesn't consume the turn.
func _resolve_feared_turn(fear_idx: int) -> void:
	battle_target_index = fear_idx
	hud.battle_log("Fear grips you -- you can only attack the %s!" % battle_units[fear_idx].name)
	if fear_idx in _targetable_indices():
		_battle_player_fight()
	else:
		hud.battle_log("...but it's out of your reach!")
		_end_player_turn()

# Heals the worst-hurt other living unit (never itself) by SHAMAN_HEAL_PCT of
# its max HP. Returns false (no-op) when nobody needs it, letting the caller
# fall through to a normal move+attack instead.
func _try_heal_ally(u: Dictionary) -> bool:
	var target = null
	var worst_missing := 0
	for other in battle_units:
		if other.ref == u.ref:
			continue
		var missing: int = other.max_hp - other.hp
		if missing > worst_missing:
			worst_missing = missing
			target = other
	if target == null:
		return false
	var heal_amt: int = max(1, int(round(float(target.max_hp) * SHAMAN_HEAL_PCT)))
	target.hp = min(target.max_hp, target.hp + heal_amt)
	play_sfx("heal")
	hud.battle_log("The %s chants, healing the %s for %d HP!" % [u.name, target.name, heal_amt])
	return true

# Druid's second priority behind healing: picks the first other living ally
# that isn't ALREADY buffed (so it spreads the buff around a squad instead
# of stacking it on one unit) and arms buffed_dmg_turns/buffed_dmg_pct --
# consumed turn-by-turn wherever pack_bonus_mult/GNOME's live bonus already
# multiply dmg, in the normal-attack branch above. Returns false (no-op,
# falls through to "hangs back") if everyone's already buffed.
func _try_buff_ally(u: Dictionary) -> bool:
	var target = null
	for other in battle_units:
		if other.ref == u.ref:
			continue
		if other.get("buffed_dmg_turns", 0) <= 0:
			target = other
			break
	if target == null:
		return false
	target.buffed_dmg_turns = DRUID_BUFF_TURNS
	target.buffed_dmg_pct = DRUID_BUFF_DMG_PCT
	play_sfx("buff")
	hud.battle_log("The %s empowers the %s!" % [u.name, target.name])
	return true

func _move_enemy_unit(u: Dictionary, attack_range: int, movement_target: Vector2i, attack_check_target: Vector2i, ignore_line: bool = false) -> void:
	# A plain int budget rather than `for i in int(u.move_range)` so Caltrops
	# (reserved terrain) can spend 2 of it on a single step instead of 1 --
	# behaves identically to the old fixed-count loop as long as nothing
	# ever costs more than 1, which is every terrain type any real battle
	# actually rolls today.
	var budget: int = int(u.move_range)
	while budget > 0:
		if _can_battle_attack(u.tile, attack_check_target, attack_range, ignore_line):
			break
		var dx := 0
		var dy := 0
		if movement_target.x != u.tile.x:
			dx = sign(movement_target.x - u.tile.x)
		if movement_target.y != u.tile.y:
			dy = sign(movement_target.y - u.tile.y)
		var options := []
		if dx != 0:
			options.append(Vector2i(dx, 0))
		if dy != 0:
			options.append(Vector2i(0, dy))
		var stepped := false
		for dir in options:
			var result := _resolve_battle_step(u.tile, dir)
			if result.moved:
				u.tile = result.tile
				if result.fell:
					var dmg := int(round(float(u.max_hp) * CLIFF_FALL_DAMAGE_PCT))
					u.hp -= dmg
					hud.battle_log("The %s falls and takes %d damage!" % [u.name, dmg])
					if u.hp <= 0:
						return
				stepped = true
				budget -= 2 if result.get("extra_cost", false) else 1
				break
		if not stepped:
			break

# Movement for a multi-tile, terrain-ignoring unit (the Brute, the Owlbear)
# -- otherwise mirrors _move_enemy_unit's movement_target/attack_check_target
# split (Brute has no "corners" trait, so the two are always equal for it and
# it still just charges target_tile directly; the Owlbear's flank tile is
# computed the same way a 1x1 cornering unit's already is, in
# _process_enemy_turn).
func _move_big_unit(u: Dictionary, movement_target: Vector2i, attack_check_target: Vector2i) -> void:
	var size: int = u.get("size", 1)
	var attack_range: int = u.get("attack_range", 1)
	for i in int(u.move_range):
		if _footprint_dist(_footprint(u.tile, size), attack_check_target) <= attack_range:
			break
		var dx := 0
		var dy := 0
		if movement_target.x != u.tile.x:
			dx = sign(movement_target.x - u.tile.x)
		if movement_target.y != u.tile.y:
			dy = sign(movement_target.y - u.tile.y)
		var options := []
		if dx != 0:
			options.append(Vector2i(dx, 0))
		if dy != 0:
			options.append(Vector2i(0, dy))
		var stepped := false
		for dir in options:
			var result := _resolve_big_unit_step(u.tile, size, dir, u.ref)
			if result.moved:
				u.tile = result.tile
				stepped = true
				break
		if not stepped:
			break

const WANDER_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# An unaware unit with nothing to engage (see _pick_enemy_target_tile's
# wander sentinel) ambles a few tiles in one random direction instead of
# idling in place -- picked once per turn rather than per-step, so it reads
# as wandering rather than jittering. Throttled by WANDER_MOVE_RANGE_CAP
# (fast units only) without ever mutating the unit's real move_range, which
# HUD display and Caltrops both read elsewhere. No attack this turn.
func _move_enemy_wander(u: Dictionary) -> void:
	var dir: Vector2i = WANDER_DIRS[randi() % WANDER_DIRS.size()]
	var budget: int = min(int(u.move_range), WANDER_MOVE_RANGE_CAP)
	var size: int = u.get("size", 1)
	for i in budget:
		if size > 1:
			var result := _resolve_big_unit_step(u.tile, size, dir, u.ref)
			if not result.moved:
				break
			u.tile = result.tile
		else:
			var result := _resolve_battle_step(u.tile, dir)
			if not result.moved:
				break
			u.tile = result.tile
			if result.fell:
				var dmg := int(round(float(u.max_hp) * CLIFF_FALL_DAMAGE_PCT))
				u.hp -= dmg
				hud.battle_log("The %s falls and takes %d damage!" % [u.name, dmg])
				if u.hp <= 0:
					return

# An Orc doesn't charge straight at the player -- it aims for the tile just
# beyond them (away from the grid's center), approaching from the outside
# in so the player ends up pinned against an edge instead of just closed on.
func _flank_target_tile(target: Vector2i) -> Vector2i:
	var center := Vector2i(BATTLE_GRID_W / 2, BATTLE_GRID_H / 2)
	var away_x := 1 if target.x >= center.x else -1
	var away_y := 1 if target.y >= center.y else -1
	return Vector2i(
		clampi(target.x + away_x, 0, BATTLE_GRID_W - 1),
		clampi(target.y + away_y, 0, BATTLE_GRID_H - 1)
	)

func _battle_victory() -> void:
	hud.battle_log("Victory!")
	_end_battle()

func _battle_flee() -> void:
	hud.battle_log("You flee the fight!")
	for u in battle_units:
		if is_instance_valid(u.ref):
			u.ref.set_battle_cooldown(BATTLE_FLEE_COOLDOWN)
	_end_battle()

func _end_battle() -> void:
	in_battle = false
	battle_units.clear()
	battle_allies.clear()
	hud.hide_battle()
	if not choosing_stat and not shop_open:
		get_tree().paused = false
	# Arrows can be spent mid-battle -- refresh the overworld quiver display
	# on the way back out, same as _on_shop_continue_pressed does for the shop.
	hud.update_quiver(_player_has_bow(), player.owned_arrows)

func _refresh_battle_display() -> void:
	# Hand Picks' Mine button only ever shows up when there's actually a
	# rock/rubble in reach -- same "conditionally visible 3rd option" shape
	# the Bow's Arrow button already uses.
	var can_mine: bool = _player_has_hand_picks() and not _targetable_rock_tiles().is_empty()
	# The "spotted" indicator needs to react live as the player moves during
	# their own turn, not just once per enemy turn -- latch here too, not
	# only inside _process_enemy_turn. spotted_you reads aware_of_player
	# directly (not _enemy_currently_sees_player) so boss-tier units --
	# always "aware" but never actually latched -- correctly show nothing;
	# a permanent "!" over a boss the whole fight would just be clutter.
	_update_enemy_awareness()
	for u in battle_units:
		u["spotted_you"] = u.get("aware_of_player", false)
	hud.update_battle_grid(BATTLE_GRID_W, BATTLE_GRID_H, battle_terrain, battle_player_tile, battle_units, player.health, player.max_health, player.level, battle_turn, _effective_target_index(), battle_player_moves_left, player.stamina, player.max_stamina, player.current_weapon, battle_menu_state, player.healing_items, battle_move_trail, battle_allies, player.has_guardian_skill, battle_skill_cooldown, player.disarmed_tile != Vector2i(-1, -1), player.owned_arrows, battle_awaiting_evasion, can_mine, player.equipped_shield.get("name", ""), player.shield_block_chance(), player.berserk_turns_remaining, player.stealth_turns_remaining, STEALTH_STAMINA_COST)
	if tutorial_active and battle_turn == "player":
		hud.show_battle_hint(_tutorial_hint_text(), _tutorial_hint_target_button())
	else:
		hud.hide_battle_hint()

# --- First-ever-battle tutorial (see trigger_battle/_setup_battle_grid for
# the trigger + enemy-tile pinning that make this sequence always
# completable). tutorial_step: 0=Move, 1=Fight, 2=Defend. ---------------

func _tutorial_action_allowed(action: String) -> bool:
	match tutorial_step:
		0:
			return action == "move"
		1:
			return action == "move" or action == "fight"
		2:
			return action == "defend"
	return true

func _tutorial_hint_text() -> String:
	match tutorial_step:
		0:
			return "Press Move, then tap a highlighted tile and Confirm to reposition."
		1:
			if battle_menu_state == "fight":
				return "Choose Attack to strike the enemy."
			return "Open Fight to attack the enemy."
		2:
			return "Choose Defend to brace for the enemy's turn."
	return ""

func _tutorial_hint_target_button() -> Control:
	match tutorial_step:
		0:
			return hud.battle_main_buttons["move"]
		1:
			if battle_menu_state == "fight":
				return hud.battle_fight_buttons["attack"]
			return hud.battle_main_buttons["fight"]
		2:
			return hud.battle_main_buttons["defend"]
	return null

func _advance_tutorial_hint() -> void:
	tutorial_step += 1

func _complete_tutorial() -> void:
	tutorial_active = false
	SaveDataScript.mark_tutorial_completed()

func _on_tutorial_skip_pressed() -> void:
	if tutorial_active:
		_complete_tutorial()
		hud.battle_log("Tutorial skipped.")
