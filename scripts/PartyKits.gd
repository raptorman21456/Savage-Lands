extends RefCounted
class_name PartyKits

# The special moves that belong to a KIND of party member rather than to a weapon (the design doc's
# "Party Specials will be added to the pool of allowed special moves, meaning party members can
# have a mix of weapon specials and specific specials"). Each entry has the same shape as a
# weapon special ({id, name, stamina_cost, dmg_mult, effect, description}); Main.gd:_ally_specials
# lists a member's kit first, then its weapon's. `stamina_cost` is paid from the member's own pool:
# stamina for the fighters, mana for the Shaman and Druid, and for the Necromancer HP (written as
# mana-worth: 1 HP per 5 mana; see hp_cost_flat / hp_cost_pct below).
#
# The effects themselves are resolved in Main.gd (search the effect id). Every number the doc gives
# is below; the costs are the ones in the design doc's Party Members tab (2026-10-08) -- anything
# marked DRAFT is not in the doc yet.

# --- Knight ---
const RALLY_DAMAGE_BONUS := 0.25          # enemies take +25% damage...
const RALLY_TURNS := 3                    # ...for 3 turns
const CHARGE_TILES := 3                   # moves 3 tiles in one direction
const CHARGE_DEFENSE_MULT := 2.0          # 2 x defense...
const CHARGE_ATTACK_MULT := 2.0 / 3.0     # ...+ 2/3 x attack, to everything in the way
const STALWART_DAMAGE_CUT := 0.5          # -50% damage taken until its next turn
const STALWART_STAMINA_PCT := 0.2         # +20% max stamina each time it is hit meanwhile

# --- Brawler ---
const WEAVE_HIT_MULT := 0.8               # two hits at 80%...
const WEAVE_ROLL_TILES := 2               # ...then a roll of up to 2 tiles
const DRAIN_PUNCH_HEAL_PCT := 0.5         # heals 50% of the damage dealt

# --- Necromancer ---
const ROT_DAMAGE_PCT := 0.10              # 10% of the target's max HP per turn
const ROT_TURNS := 5                      # DRAFT: not in the doc (same length as Poison)
const SKELETON_HP := 1
const SKELETON_DAMAGE := 4.0
const SKELETON_MOVE := 1
const SKELETON_HP_COST := 5               # HP paid per skeleton raised

# --- Shaman ---
const SOOTHING_RAIN_PCT := 0.2            # heals 20% of max HP
const AURA_RADIUS := 2                    # "within 2 tiles"
const CHARM_TURNS := 2                    # How Charming lasts 2 turns...
const CHARM_RADIUS := 4                   # ...at 4 tiles

# --- Wolf ---
const DRIVE_BY_MULT := 1.4
const FEED_MULT := 1.5
const FEED_HP_THRESHOLD := 0.2            # Feed bites harder under 20% HP
const FEED_KILL_HEAL := 5                 # heals 5 HP on a kill...
const FEED_KILL_STAMINA := 20             # ...and refunds 20 stamina
const NIPPER_MULT := 0.8
const NIPPER_SLOW_CHANCE := 0.5           # 50% to halve the enemy's speed

# --- Druid ---
const DRUID_HEAL_PCT := 0.25              # heals 25% of the target's max HP...
const DRUID_HEAL_MAGIC_DIV := 3.0         # ...plus magic / 3 (magic / 2 once upgraded at the Wizard's Tower)
const DRUID_HEAL_MAGIC_DIV_UPGRADED := 2.0
const DRUID_BUFF_MULT := 1.5              # buff: target deals 1.5x damage...
const DRUID_BUFF_TURNS := 3               # ...for 3 turns
const DRUID_SPRINT_MOVE_MULT := 2.0       # movement spell: doubles her move tiles...
const DRUID_SPRINT_FLAT_BONUS := 5.0      # ...and her attack is flat (attack / 2) + 5 while it lasts
const DRUID_SPRINT_ATTACK_DIV := 2.0

# --- Guardian ---
const BODY_SLAM_MULT := 1.3
const BODY_SLAM_STUN_CHANCE := 0.15
const HAYMAKER_MULT := 1.5
const BELLOW_FLAT := 20.0                 # (20) + 0.67 x the Guardian's max HP to every enemy
const BELLOW_HP_MULT := 0.67

# --- Marksman ---
const MARKSMAN_BOW_CRIT_MULT := 1.5       # crit chance x1.5 with a bow

# --- Rogue ---
const ROGUE_STEAL_CHANCE := 0.25          # a regular hit may steal 1 gold instead of damaging
const ROGUE_KNIFE_MULT := 1.25
const PICKPOCKET_COINS := 3
const JUGULAR_BLEED_TURNS := 2
const LONDON_SLASH_MULT := 0.6
const LONDON_SLASHES_MIN := 3
const LONDON_SLASHES_MAX := 7

const KITS := {
	"knight": [
		{"id": "knight_rallying_cry", "name": "Rallying Cry", "stamina_cost": 25, "dmg_mult": 0.0, "effect": "rallying_cry",
			"description": "A roar that rattles every enemy: they all take +25% damage from everyone for 3 turns."},
		{"id": "knight_charge", "name": "CHARGE!!", "stamina_cost": 50, "dmg_mult": 1.0, "effect": "charge",
			"description": "Run 3 tiles in one direction, over any terrain, hitting everything in the way for 2x defense plus 2/3 of attack."},
		{"id": "knight_stalwart", "name": "Stalwart", "stamina_cost": 10, "dmg_mult": 0.0, "effect": "stalwart",
			"description": "Brace: damage taken until the next turn is halved, each hit taken restores 20% of max stamina, and nothing can knock the Knight back."},
	],
	"brawler": [
		{"id": "brawler_sucker_punch", "name": "Sucker Punch", "stamina_cost": 30, "dmg_mult": 1.0, "effect": "sucker_punch",
			"description": "A guaranteed crit on an enemy that is still at full HP."},
		{"id": "brawler_dodge_and_weave", "name": "Dodge and Weave", "stamina_cost": 45, "dmg_mult": WEAVE_HIT_MULT, "effect": "dodge_and_weave",
			"description": "Strike twice at 80% damage, then roll up to 2 tiles in a direction you choose."},
		{"id": "brawler_drain_punch", "name": "Drain Punch", "stamina_cost": 40, "dmg_mult": 1.0, "effect": "drain_punch",
			"description": "A punch that heals the Brawler for half the damage it deals."},
	],
	"necromancer": [
		# Costs 10 HP plus 15% of max HP (hp_cost_flat / hp_cost_pct; Main.gd:_kit_special_for).
		{"id": "necromancer_curse_of_rot", "name": "Curse of Rot", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "curse_of_rot", "hp_cost_flat": 10, "hp_cost_pct": 0.15,
			"description": "Rots an enemy from within: it loses 10% of its max HP every turn for 5 turns, and if it dies while cursed the kill is the Necromancer's. Costs 10 HP plus 15% of max HP."},
		# Takes the Necromancer to 1 HP to cast (the cost is worked out when the menu opens).
		{"id": "necromancer_revival_blessing", "name": "Revival Blessing", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "revive", "cost_all": true,
			"description": "Raise a downed ally to full HP. It takes everything the Necromancer has: HP drops to 1."},
		# 5 HP per skeleton, one for each enemy slain in the last battle; needs 5 HP + 40% of max HP to cast
		# (require_hp_*; both worked out when the menu opens).
		{"id": "necromancer_summon_the_dead", "name": "Summon the Dead", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "summon_dead", "per_skeleton": true, "require_hp_flat": 5, "require_hp_pct": 0.4,
			"description": "Raise a 1 HP skeleton (4 damage) for every enemy slain in the last battle, for 5 HP each. They charge the nearest enemy. Needs 5 HP plus 40% of max HP to cast."},
	],
	"shaman": [
		{"id": "shaman_how_charming", "name": "How Charming", "stamina_cost": 40, "dmg_mult": 0.0, "effect": "how_charming",
			"description": "Her charms reach further: talisman effects are shared out to allies within 4 tiles for 2 turns."},
		{"id": "shaman_soothing_rain", "name": "Soothing Rain", "stamina_cost": 50, "dmg_mult": 0.0, "effect": "soothing_rain",
			"description": "A gentle rain heals every ally within 2 tiles for 20% of their max HP."},
		{"id": "shaman_cleansing_chant", "name": "Cleansing Chant", "stamina_cost": 30, "dmg_mult": 0.0, "effect": "cleansing_chant",
			"description": "Washes one negative status off every ally within 2 tiles -- or every affliction off a single ally."},
	],
	# --- the older kits (the doc's Party Members tab) ---
	"wolf": [
		{"id": "wolf_drive_by", "name": "Drive-By", "stamina_cost": 35, "dmg_mult": DRIVE_BY_MULT, "effect": "drive_by", "keeps_turn": true,
			"description": "Hit hard, dash to the tile past the enemy, and get ONE more regular attack."},
		{"id": "wolf_feed", "name": "Feed", "stamina_cost": 25, "dmg_mult": 1.0, "effect": "feed",
			"description": "Bites 50% harder into an enemy under 20% HP. A kill heals the Wolf 5 HP and refunds 20 stamina."},
		{"id": "wolf_nipper", "name": "Nipper", "stamina_cost": 10, "dmg_mult": NIPPER_MULT, "effect": "nipper",
			"description": "A quick nip at 80% damage with a 50% chance to halve the enemy's speed."},
	],
	"druid": [
		# The doc's names and costs (2026-10-09): Restore 40 mana, Empower 30 mana, Vitalize 40 mana.
		{"id": "druid_heal", "name": "Restore", "stamina_cost": 40, "dmg_mult": 0.0, "effect": "druid_heal",
			"description": "Heal an ally for 25% of their max HP plus a third of the Druid's magic (a half once upgraded at the Wizard's Tower)."},
		{"id": "druid_buff", "name": "Empower", "stamina_cost": 30, "dmg_mult": 0.0, "effect": "druid_buff",
			"description": "An ally deals 1.5x damage for 3 turns."},
		{"id": "druid_sprint", "name": "Vitalize", "stamina_cost": 40, "dmg_mult": 0.0, "effect": "sprint", "keeps_turn": true,
			"description": "Doesn't end the turn: double the Druid's movement, but her attack drops to a flat (attack / 2) + 5."},
	],
	"guardian": [
		{"id": "guardian_taunt", "name": "Taunt", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "taunt", "keeps_turn": true,
			"description": "Draw every enemy onto the Guardian (and brace like Guard). It does NOT end the turn."},
		{"id": "guardian_body_slam", "name": "Body Slam", "stamina_cost": 35, "dmg_mult": BODY_SLAM_MULT, "effect": "body_slam",
			"description": "Slam with the Guardian's DEFENSE instead of its attack at 130% damage. 15% chance to stun."},
		{"id": "guardian_haymaker", "name": "Haymaker", "stamina_cost": 50, "dmg_mult": HAYMAKER_MULT, "effect": "haymaker",
			"description": "A crushing swing at 150% damage that always stuns."},
		# DRAFT cost -- the doc gives none.
		{"id": "guardian_bellow", "name": "Earbursting Bellow", "stamina_cost": 60, "dmg_mult": 0.0, "effect": "bellow",
			"description": "20 + 0.67 x the Guardian's max HP to EVERY enemy -- and you take the same unless you time it right."},
	],
	"marksman": [
		# The Bow's specials are its special arrows, fired from the quiver you share (no stamina).
		{"id": "marksman_flame_arrow", "name": "Flame Arrow", "stamina_cost": 0, "dmg_mult": 1.0, "effect": "ally_arrow_flame",
			"description": "Spends one of your Flame Arrows: a small hit plus half the Marksman's attack, and the target burns."},
		{"id": "marksman_freeze_arrow", "name": "Freeze Arrow", "stamina_cost": 0, "dmg_mult": 1.0, "effect": "ally_arrow_freeze",
			"description": "Spends one of your Freeze Arrows: 5 damage and the target is frozen for 2-4 turns."},
		{"id": "marksman_bomb_arrow", "name": "Bomb Arrow", "stamina_cost": 0, "dmg_mult": 1.0, "effect": "ally_arrow_bomb",
			"description": "Spends one of your Bomb Arrows: 20 damage in a 3x3 blast -- you and your allies included."},
	],
	"rogue": [
		{"id": "rogue_pickpocket", "name": "Pickpocket", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "pickpocket",
			"description": "No damage: steal 3 coins. Ends the turn, but the Rogue moves 1 extra tile next turn."},
		{"id": "rogue_jugular", "name": "Aim for the Jugular!", "stamina_cost": 40, "dmg_mult": 1.0, "effect": "jugular",
			"description": "Always a crit, and the wound bleeds."},
		{"id": "rogue_londons_welcome", "name": "London's Welcome", "stamina_cost": 50, "dmg_mult": LONDON_SLASH_MULT, "effect": "londons_welcome",
			"description": "3-7 quick slashes at 60% damage. If one misses they all miss."},
	],
}

# Effects that are not aimed at an enemy in reach: _battle_perform_attack does not refuse them for
# "no enemy in range".
const NO_ENEMY_NEEDED := ["rallying_cry", "charge", "stalwart", "summon_dead", "how_charming", "soothing_rain", "cleansing_chant", "channel", "revive", "taunt", "sprint", "druid_heal", "druid_buff"]

static func specials_for(kind: String) -> Array:
	return KITS.get(kind, [])
