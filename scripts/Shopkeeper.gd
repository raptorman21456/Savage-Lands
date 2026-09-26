extends Node
class_name Shopkeeper

# The shop's left-hand portrait/textbox (HUD.gd's shop_keeper_box) speaks in
# two ways: these generic barks for shop-flow moments (entering, leaving,
# buying, failing to afford something), and each catalog item's own
# "shop_description" field (Weapons/Potions/Armor/Shields/Enchantments) when
# the player hovers its row -- see HUD.gd:_hook_shopkeeper_hover.
#
# Each category is a short list, not a single fixed line, so it isn't the
# exact same bark every single time -- get_line() picks one at random.
# Routed through GameText.gd (key scheme "shopkeeper.<category>.<index>")
# like everything else editable in text/strings.json.
static var LINES := {
	"enter": [
		"Welcome, welcome! Don't be shy, have a look.",
		"Back again? Good, good -- come in.",
		"Ah, a customer. Let's see what you need.",
	],
	"buy_success": [
		"A fine choice, if I do say so myself.",
		"Pleasure doing business.",
		"You won't regret that one.",
	],
	"buy_fail": [
		"That's a bit rich for your purse, isn't it?",
		"Come back when you've got the coin.",
		"I don't run a charity, friend.",
	],
	"exit": [
		"Come back soon, now!",
		"Safe travels out there.",
		"Mind the goblins on your way out.",
	],
}

static func get_line(category: String) -> String:
	var options: Array = LINES.get(category, [])
	if options.is_empty():
		return ""
	return options[randi() % options.size()]

# Per-weapon-type reactions, layered on top of a hovered weapon's own flat
# shop_description -- up to 3 tiers per type: "base" (always eligible),
# "high_quality" (Masterwork tier or better -- see HIGH_QUALITY_MIN_RANK),
# and "familiar" (once the run's reached a late-game world -- the
# shopkeeper's had more time getting to know this particular barbarian).
# Every type below is filled in as a worked example (tone + the 3/3/3
# shape) -- yours to keep, edit, or replace wholesale directly in
# text/strings.json (key scheme "shopkeeper.item.<weapon_id>.<tier>.<index>").
# get_item_line() below falls back to the item's own shop_description
# whenever a tier ends up with nothing in it, so deleting any line (or a
# whole tier) back down to empty never regresses anything. Club has no
# high_quality set on purpose -- make_variant() is never called on it, so
# it never carries a tier_name/rank at all and that bucket can never fire.
const HIGH_QUALITY_MIN_RANK := 3
const FAMILIAR_MIN_WORLD_INDEX := 6
static var ITEM_LINES := {
	"club": {
		"base": [
			"It's a stick. An excellent, dependable stick. Everyone starts somewhere.",
			"Free, sturdy, and it's never once let a barbarian down. Low bar, sure, but it clears it.",
			"Not much to brag about, but it swings true and costs you nothing to keep around.",
		],
		"high_quality": [],
		"familiar": [
			"Still keeping that old club around, I see. Sentimental, or just cheap? Either way, I approve.",
			"That thing's outlasted better weapons in your hands. There's something to be said for that.",
			"You could've upgraded ages ago. Something tells me you just like the club.",
		],
	},
	"spear": {
		"base": [
			"A spear'll keep 'em at arm's length. Smart, for someone your size.",
			"Reach beats reflexes, every time. Take it from someone who's still got both eyes.",
			"Pointy end goes towards the trouble. Rest explains itself.",
		],
		"high_quality": [
			"Now THAT's a spear. Balanced like it wants to be thrown, sharp like it doesn't need to be.",
			"You could hunt gods with that thing. Try not to lose it.",
			"Careful waving that one around in here. I like my walls where they are.",
		],
		"familiar": [
			"Still favoring the spear, eh? Figured you would -- you always did like keeping things at a distance.",
			"That's the same style you had back on the Plains. Some things don't change. Good thing, too.",
			"You and that spear. At this point I'd be more surprised if you switched.",
		],
	},
	"greatsword": {
		"base": [
			"Both hands, full commitment. No room in your grip for hesitation with one of these.",
			"That blade's got some heft to it. Swing it right and everything nearby feels it too.",
			"A greatsword doesn't ask permission. Neither should you, wielding one.",
		],
		"high_quality": [
			"Now that's a slab of steel. Wide enough to clear a room, if your arms are up to it.",
			"I've seen smaller trees than that blade. Mind the furniture.",
			"That edge could split a shield in half. Try not to split anything you meant to keep.",
		],
		"familiar": [
			"Still swinging the big one, I see. Suits you -- you were never one for subtlety.",
			"You've gotten better with that greatsword since you first walked in here. It shows.",
			"That's the same weight class you started with. A lot of barbarians switch it up. Not you.",
		],
	},
	"hammer": {
		"base": [
			"Subtlety's not really the hammer's strong suit. Neither, I'd wager, is yours.",
			"Hit something hard enough with that and it stops being your problem. Usually.",
			"Slow to swing, but nothing stays standing where it lands.",
		],
		"high_quality": [
			"That head alone could crack a boulder. I'd hate to be on the other end of a swing.",
			"Forged heavy, swings heavier. Whatever you hit isn't getting back up on its own schedule.",
			"That's not a hammer, that's an argument-ender.",
		],
		"familiar": [
			"Still knocking things flat with that hammer? Wouldn't have you any other way.",
			"You've left a few dents in my counter just carrying that thing in. No complaints, though.",
			"A slower weapon for a patient fighter. Didn't peg you for patient, back when we met.",
		],
	},
	"battle_axe": {
		"base": [
			"An axe like that finishes what other weapons start. Handy, if you're not the finishing type.",
			"Good and heavy on the swing. Whatever's already hurting won't enjoy the follow-up.",
			"Simple tool. Simple job. Chop first, ask never.",
		],
		"high_quality": [
			"That edge is honed for exactly one purpose, and it isn't woodwork.",
			"Something already wounded sees that axe coming and knows how the story ends.",
			"Balanced beautifully for a killing blow. Ugly thought, lovely craftsmanship.",
		],
		"familiar": [
			"You always did go for the axe when something was already on its last legs. Ruthless. Efficient.",
			"Still finishing fights the same way you started them with me -- decisively.",
			"That axe has seen more last stands than I care to count. Yours mostly ending them.",
		],
	},
	"dagger": {
		"base": [
			"Small blade, quick hands. Good for someone who'd rather not be seen coming.",
			"That's not for a fair fight. Good -- fair fights are for people who lose otherwise.",
			"Twice as fast as it looks, if you know how to use it. Do you?",
		],
		"high_quality": [
			"That edge is faster than most eyes can track. Whoever it's aimed at won't see the second cut coming.",
			"Beautifully balanced. The kind of blade that finds a gap before you've decided where to aim it.",
			"Quiet, quick, and twice as dangerous as it looks. My favorite kind of weapon.",
		],
		"familiar": [
			"Still darting in and out with that dagger. Never did have the patience for a slower blade, did you?",
			"You've gotten fast with that thing. Faster than when you first walked through that door, anyway.",
			"That dagger's seen a lot of backs it probably shouldn't have. Not my business how you win.",
		],
	},
	"bow": {
		"base": [
			"Keep your distance, let the arrow do the arguing. Sound strategy, for someone who can aim.",
			"Nothing wrong with winning a fight before it gets close enough to matter.",
			"A bow rewards patience. Pull, breathe, loose. The math handles the rest.",
		],
		"high_quality": [
			"That draw weight alone could punch through a shield. Wherever you're aiming, it's arriving.",
			"Craftsmanship like that doesn't miss because of the bow. Only because of the archer.",
			"Every string on that thing sings true. Whatever's on the other end of your next shot won't enjoy it.",
		],
		"familiar": [
			"Still keeping your distance, I see. Never did like getting your hands dirty, did you?",
			"You've gotten sharper with that bow since your first visit. Fewer arrows wasted, more targets down.",
			"That's the same bow you walked in with, isn't it? Well-loved. Well-used.",
		],
	},
	"knuckle_gloves": {
		"base": [
			"No blade, no shaft, just knuckle and bone. Brave choice, or a foolish one. Time will tell.",
			"Fists like that rattle more than just the target's teeth.",
			"Closest range in the shop. Either you're confident, or you don't have a choice.",
		],
		"high_quality": [
			"Reinforced knuckles like that could put a dent in a shield, let alone a skull.",
			"Every hit off those gloves lands like it means it. That's not a metaphor, that's dentistry.",
			"You'd need a steady jaw to wear those and keep your own teeth. Good thing they're not for your jaw.",
		],
		"familiar": [
			"Still fighting bare-knuckle, more or less. Some habits from the Plains just don't leave.",
			"You've got a lot more confidence swinging those fists now than you did when we met.",
			"No weapon at all, really, just very committed hands. Works for you, somehow.",
		],
	},
	"hand_picks": {
		"base": [
			"Built for breaking rock, not skulls. Does both, in the right hands.",
			"Cheap, sturdy, and surprisingly nasty up close. A miner's best friend, and now yours.",
			"Not much to look at, but it never seems to run out of tricks.",
		],
		"high_quality": [
			"That pick's been through more rockfall than most and come out sharper for it.",
			"Sturdy enough to crack stone, sharp enough to do a lot worse. Rare combination.",
			"Whoever forged that one wasn't thinking about mining anymore by the end.",
		],
		"familiar": [
			"Still carrying a miner's tool into a fight. Practical. I respect that more than I first let on.",
			"You've made that pick do more work than any quarry ever asked of it.",
			"Humble little tool, big body count. You've made quite a pair.",
		],
	},
}

# weapon_id is the base TYPE's id (e.g. "spear"), not a rolled variant's own
# id (which carries a "_<tier>_<material>" suffix) -- see Weapons.gd:
# get_base_type. tier_rank is the rolled variant's TIERS.rank (0=Broken..
# 5=Mythic); world_index is Main.gd's current_world_index. fallback is the
# item's own flat shop_description, used whenever the tier picked below
# turns out to have no lines written for this weapon_id yet.
static func get_item_line(weapon_id: String, tier_rank: int, world_index: int, fallback: String) -> String:
	var tiers: Dictionary = ITEM_LINES.get(weapon_id, {})
	if tiers.is_empty():
		return fallback
	if world_index >= FAMILIAR_MIN_WORLD_INDEX:
		var familiar: Array = tiers.get("familiar", [])
		if not familiar.is_empty():
			return familiar[randi() % familiar.size()]
	if tier_rank >= HIGH_QUALITY_MIN_RANK:
		var high_quality: Array = tiers.get("high_quality", [])
		if not high_quality.is_empty():
			return high_quality[randi() % high_quality.size()]
	var base: Array = tiers.get("base", [])
	if not base.is_empty():
		return base[randi() % base.size()]
	return fallback
