extends RefCounted
class_name ItemLore

# The flavour line ("lore", a little like Hollow Knight) every weapon, armour, shield, piece of clothing and talisman shows on its
# card, and for a talisman the short overview of what it does that sits beside it. ALL OF THIS TEXT IS A FIRST DRAFT: rewrite any
# line freely -- nothing else reads it but the inventory's detail panel, and a missing id simply shows no lore.
# (The real, exact rules text stays in Weapons.gd / Armor.gd / Shields.gd / Clothing.gd / Talismans.gd.)

const WEAPONS := {
	"club": "Subtle as a falling tree.",
	"spear": "Reach is just patience with a point.",
	"greatsword": "Too heavy to be elegant.",
	"hammer": "It remembers every wall.",
	"battle_axe": "Made for one job.",
	"dagger": "Quick and quiet.",
	"bow": "Let them do all the walking.",
	"knuckle_gloves": "Remembers every brawl.",
	"hand_picks": "Built for breaking rock.",
	"staff": "A branch that remembers being a tree.",
}

# A Mythic weapon's own line, by its base weapon.
const MYTHICS := {
	"spear": "It has outlived everyone who named it.",
	"greatsword": "Three o's, and every one of them earned.",
	"hammer": "Always second best. Never second to land.",
	"battle_axe": "It has never once needed sharpening.",
	"dagger": "Whatever it is, it is for something.",
	"bow": "It does not miss. It just does not care.",
	"knuckle_gloves": "Made by an uncle, for an uncle's kind of argument.",
	"hand_picks": "Season them well and nothing sticks.",
}

const ARMOR := {
	"armor_rags": "Better than nothing, barely.",
	"armor_gambeson": "Quilted layers and quiet courage.",
	"armor_thornmail": "It hurts to hug you.",
	"armor_fortress": "A wall you wear.",
	"armor_dragonskin": "Taken from something that didn't want to share.",
	"armor_stonehide": "Worn so long it set.",
	"armor_bastion": "Built to be stood behind.",
	"armor_martyr": "It loves you more the worse you look.",
	"armor_cinder": "Still smouldering from its last owner.",
	"armor_bloodrage": "Still warm, somehow.",
	"armor_shadowweave": "Cut from where the light stopped.",
	"armor_windrunner": "Lighter than a promise.",
	"armor_spellward": "Stitched with something that listens.",
	"armor_warden": "It watches over everyone near you but its wearer.",
}

const SHIELDS := {
	"shield_buckler": "Better than a bare arm.",
	"shield_heavy": "Too solid to move, and so are you.",
	"shield_bulwark": "A slow, steady wall.",
	"shield_phantom": "Cold to the touch, and not quite there.",
	"shield_brawler": "Dented in all the right places.",
}

const CLOTHING := {
	"cloth_cap": "Keeps the rain off.",
	"cloth_hood": "Keeps the rain off and secrets in.",
	"cloth_pelt_hood": "Its previous owner would like it back.",
	"cloth_tunic": "Patched at every mile.",
	"cloth_jerkin": "A little thick, a little safe.",
	"cloth_cloak": "Heavy, itchy, warm.",
	"cloth_sandals": "Made for walking, not for fighting.",
	"cloth_boots": "Resoled twice.",
	"cloth_trail_boots": "They know the way better than you do.",
}

# Talismans, in the game's order: id -> {group, overview (what it does, short, numbers as in Talismans.gd), lore}.
const TALISMANS := {
	"ember_charm": {"group": "Offense", "overview": "10% chance for an attack to set the target on fire (2% per hit on multi-hit moves).", "lore": "A coal that never went out, sewn into a scrap of cloth."},
	"wolf_fang": {"group": "Offense", "overview": "Traitor Wolves turn up more often and are likelier to join you. Adds a party slot only a Fickle Wolf can fill; wolves stay 5 battles longer.", "lore": "Pulled from a wolf that chose the wrong pack. It still listens for a howl."},
	"berserkers_knot": {"group": "Offense", "overview": "+100% damage while at or below 20% HP.", "lore": "Tie it tight and stop counting your wounds."},
	"duelists_coin": {"group": "Offense", "overview": "-15% damage on every hit, but crits deal 300% damage and land 5% more often.", "lore": "Heads, you win by a hair. Tails, you were never going to lose."},
	"whetstone_pendant": {"group": "Offense", "overview": "Whoever lands the first hit each battle (you or an ally) deals 50% more damage with it.", "lore": "Hums faintly whenever a blade is drawn."},
	"fletchers_ring": {"group": "Offense", "overview": "No limit on carried special arrows, but they cost 10% more.", "lore": "Worn smooth by a thousand nocks."},
	"stone_amulet": {"group": "Defense", "overview": "Doubles what your weapon's material does: its damage, price and stamina swings, and its passive.", "lore": "Cold, heavy, and certain of itself."},
	"turtle_shell": {"group": "Defense", "overview": "The current can't sweep you off a water tile without asking first.", "lore": "Slow is a kind of safe."},
	"wind_chime": {"group": "Defense", "overview": "Your Taunt enrages enemies past reason: each attacks whoever is nearest, even each other.", "lore": "A pretty sound that makes the wrong people very angry."},
	"guardian_knot": {"group": "Defense", "overview": "Your allies gain +40 Defense and Fortitude.", "lore": "Tied by someone who wanted you protected."},
	"iron_will_band": {"group": "Defense", "overview": "10% chance to survive a killing blow with 1 HP (once a battle).", "lore": "Stubbornness, hammered flat and worn on the wrist."},
	"cliffwalkers_bead": {"group": "Defense", "overview": "Cliff falls deal no damage, and you can attack up a ledge or cliff with any weapon.", "lore": "Strung by someone who never once looked down."},
	"moss_charm": {"group": "Sustain", "overview": "Regain 1 HP at the start of each of your turns, plus 1 more for every 20 max HP.", "lore": "Soft, damp, quietly mending."},
	"healers_knot": {"group": "Sustain", "overview": "Potions and food heal 25% more.", "lore": "A bandage someone never took off."},
	"bloodstone": {"group": "Sustain", "overview": "Heal 3 HP whenever an enemy falls.", "lore": "It drinks what the battlefield spills, and shares."},
	"second_wind_whistle": {"group": "Sustain", "overview": "Regain 5 extra stamina each battle turn.", "lore": "One short note, and your lungs remember how."},
	"deep_lung_charm": {"group": "Sustain", "overview": "Every weapon special costs 5 less stamina.", "lore": "A breath held longer than any sailor's."},
	"lucky_clover": {"group": "Economy", "overview": "Doubles the chance of every secondary effect: burning, bleeding, stuns, extra strikes and other on-hit procs.", "lore": "Four leaves, and the fourth is the lucky one."},
	"merchants_coin": {"group": "Economy", "overview": "+10% coins from every source.", "lore": "Spent ten thousand times, and it always comes home."},
	"hagglers_tooth": {"group": "Economy", "overview": "-10% off every shop price.", "lore": "Bared at the counter, it does most of the talking."},
	"gilded_scarab": {"group": "Economy", "overview": "+0.125 attack power and +0.1 damage reduction for every coin you are holding.", "lore": "Hungry for coins."},
	"tax_collectors_seal": {"group": "Economy", "overview": "20% chance for any landed hit to drop an extra coin (bosses excluded).", "lore": "Stamped on every wound it ever caused."},
	"scholars_quill": {"group": "Utility", "overview": "+30% experience gained.", "lore": "Knowledge is heavy; it pays well."},
	"swift_feather": {"group": "Utility", "overview": "+35% movement speed in the field.", "lore": "Lighter than the thought of leaving."},
	"pathfinders_compass": {"group": "Utility", "overview": "Every town and outskirts venue shows on your map immediately.", "lore": "Its needle points to where you haven't been yet."},
	"gamblers_die": {"group": "Utility", "overview": "Better odds at the Wishing Well and the horse races.", "lore": "Every face is a six if you believe hard enough."},
	"anglers_hook": {"group": "Utility", "overview": "A wider bite window and rarer catches at the fishing hole.", "lore": "Patience, barbed."},
	"phoenix_ash": {"group": "Utility", "overview": "Once per run, survive a killing blow with 1 HP.", "lore": "What is left when something refuses to end."},
	"glass_cannon_charm": {"group": "Wildcard", "overview": "-50% max HP, but +75% damage on everything you deal.", "lore": "Beautiful, brittle, and loud."},
	"vampires_pact": {"group": "Wildcard", "overview": "Heal 25% of the damage you deal, but potions and food no longer work on you.", "lore": "It always takes its cut back."},
	"momentum_chain": {"group": "Wildcard", "overview": "Each hit you land without being hit adds +8% damage, uncapped. Being hit breaks the chain and stuns you.", "lore": "Every link is a promise not to flinch."},
	"whirlwind_charm": {"group": "Wildcard", "overview": "Every melee attack strikes twice, but all damage is cut to 40%.", "lore": "Two strikes, half the weight, all the noise."},
	"weapon_whisperer": {"group": "Wildcard", "overview": "Choose any 3 learned specials from any weapon as your loadout, but every special costs 30% more stamina.", "lore": "Every blade tells it a secret, and it keeps them all."},
	"chaos_shard": {"group": "Wildcard", "overview": "Every hit deals between 50% and 160% of its normal damage, rerolled each time.", "lore": "A piece of a larger thing that never held still."},
	"last_stand_idol": {"group": "Wildcard", "overview": "Every attack instantly kills a regular enemy (bosses unaffected), but your HP is locked at 1.", "lore": "It grants the only wish worth making, and takes everything else."},
	"bloodmoon_fang": {"group": "Wildcard", "overview": "Each hit you land stacks Bloodlust (+5% damage, +7.5% move speed). 3 turns with no hit landed by anyone crashes it, halving all your stats.", "lore": "Sharpened under a red sky; always hungry."},
	"ironclad_ward": {"group": "Wildcard", "overview": "You can only Move every other turn, but your defense is multiplied by 250%.", "lore": "A wall that agreed to follow you around."},
	"wildfire_core": {"group": "Wildcard", "overview": "A burning enemy that dies explodes for 3x its fire damage, hurting and igniting everything nearby, allies and you included.", "lore": "A spark that learned to hunt."},
	"clapback": {"group": "Sorcery", "overview": "Whenever you cast a spell, a 20% chance you also strike the nearest enemy for your STR + half your MAG, with +30% damage if it is a mage.", "lore": "The last word is never the spell's."},
	"heavy_cloak": {"group": "Sorcery", "overview": "+1 Resilience and Fortitude for every 3 Magic you have.", "lore": "The more you know, the less the world can reach you."},
	"spell_bank": {"group": "Sorcery", "overview": "Regain 5% of your max mana at the end of each of your turns (the Necromancer heals 5% of her max HP).", "lore": "Interest, paid in power."},
	"dreamcatcher": {"group": "Sorcery", "overview": "Spells cost 33% less mana (a Necromancer pays 33% less HP).", "lore": "It lets the cost of a spell slip through its web."},
	"snail_shell": {"group": "Sorcery", "overview": "Spells have +25% potency.", "lore": "Slow, spiralled, and heavy with everything it has ever carried."},
	"lingering_echo": {"group": "Sorcery", "overview": "10% chance for a spell to cast twice: the second cast is free, and you choose its target again.", "lore": "A word said in a stone room comes back."},
	"blazing_battery": {"group": "Sorcery", "overview": "I CAST FIREBALL skips its charging turn.", "lore": "Charged once, burns forever."},
	"loud_whistle": {"group": "Sorcery", "overview": "Every summon is doubled: twice the skeletons, twice the spectres.", "lore": "Too loud for the living. The dead hear it twice."},
}

# A weapon's lore by its variant (a Mythic has its own, the rest go by base weapon).
static func weapon(variant: Dictionary, base_id: String) -> String:
	if str(variant.get("tier_name", "")) == "Mythic":
		return str(MYTHICS.get(base_id, ""))
	return str(WEAPONS.get(base_id, ""))

static func talisman(id: String) -> Dictionary:
	return TALISMANS.get(id, {})
