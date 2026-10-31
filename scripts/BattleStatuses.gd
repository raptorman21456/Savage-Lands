extends RefCounted
class_name BattleStatuses

# What a unit on the battle grid is currently afflicted or blessed with, as the battle screen shows it: the party cards'
# chips, the popup over a hovered unit, and the details box (where hovering a status reads what it does). Each entry is
# {"id", "name", "detail" ("2 turns", "stack x3"...), "desc" (what it does), "good" (a blessing, not a curse)}.
#
# The numbers in the descriptions are the game's own (Main.gd constants, the design doc's "Status Conditions"); if a
# constant moves, edit the line here.

const TEXT := {
	"poison": ["Poison", "Loses 10% of its max HP at the end of every turn.", false],
	"burn": ["Burning", "Takes max HP / 15 damage every turn, and deals 25% less damage. It lasts until it steps into water.", false],
	"bleed": ["Bleeding", "Loses 10% of its max HP at the end of every turn. Each tile it moves adds a turn.", false],
	"frozen": ["Frozen", "Cannot act, and takes 20% more damage.", false],
	"concussed": ["Concussed", "Dazed: each turn it may strike itself instead of acting.", false],
	"blind": ["Blinded", "Attacks usually miss, but any hit that lands is a guaranteed crit.", false],
	"vulnerable": ["Vulnerable", "Takes 25% more damage from every hit.", false],
	"stunned": ["Stunned", "Skips its next turn.", false],
	"winding_up": ["Winding up", "Is preparing a heavy attack that lands on its next turn.", false],
	"disarmed": ["Disarmed", "Its weapon is on the ground: it fights bare-handed until it reaches the tile where the weapon landed.", false],
	"rot": ["Rot", "Rots from within, losing a share of its max HP at the start of its turn. If it dies cursed, the kill belongs to the Necromancer.", false],
	"buffed": ["Emboldened", "Hits harder than usual.", true],
	"stealth": ["Stealth", "Enemies that haven't noticed it can't target it. Its next attack is a guaranteed crit and ends the stealth.", true],
	"berserk": ["Berserk", "+25% damage dealt, 25% less damage taken and 1 more tile of movement.", true],
	"rage_building": ["Rage building", "Every 5th enemy to fall sends you into Berserk. The count carries from battle to battle.", true],
	"defending": ["Defending", "Takes half damage from the coming enemy turn, and recovers stamina.", true],
	"taunting": ["Taunting", "Every enemy is forced onto it on the coming enemy turn.", true],
	"empowered": ["Empowered", "Deals extra damage (a Druid's Empower).", true],
	"charm": ["Charmed talismans", "Its talismans reach allies who stand close (a Shaman's How Charming).", true],
	"charging": ["Charging", "Gathering a fireball and can't move. Release it next turn.", true],
	"bloodrage": ["Bloodrage", "Every hit it takes stacks extra damage dealt, for a couple of turns.", true],
	"bloodboost": ["Bloodboost", "Every hit landed stacks +5% damage and +7.5% move speed. Three turns with no hit landed by anyone crash it.", true],
	"bloodcrash": ["Bloodcrash", "The Bloodboost crashed: every combat stat is halved for the rest of the battle.", false],
	"potion_attack": ["Attack Potion", "Deals 25% more damage.", true],
	"potion_resilience": ["Resilience Potion", "Takes 20% less damage.", true],
	"potion_energy": ["Energy Potion", "Moves one tile farther.", true],
	"skip": ["Reeling", "Loses its next turn.", false],
	"downed": ["Downed", "Knocked out of the fight. A Revival Blessing can stand them back up.", false],
}

static func entry(id: String, detail: String = "") -> Dictionary:
	var t: Array = TEXT.get(id, [id.capitalize(), "", false])
	return {"id": id, "name": t[0], "detail": detail, "desc": t[1], "good": t[2]}

# The ids of the statuses in `entries` that have a picture (UIIcons.status_icon), each once, in order: what an icon tray shows.
static func ids_with_icons(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var id: String = str(e.get("id", ""))
		if UIIcons.status_icon(id) != "" and not out.has(id):
			out.append(id)
	return out

static func _turns(n: int) -> String:
	return "%d turn%s" % [n, "" if n == 1 else "s"]

# An enemy on the grid (a Main.battle_units dictionary).
static func for_enemy(u: Dictionary) -> Array:
	var out: Array = []
	if u.get("winding_up", false):
		out.append(entry("winding_up", "next turn"))
	if int(u.get("poison_turns", 0)) > 0:
		out.append(entry("poison", _turns(int(u.poison_turns))))
	if u.get("burning", false):
		out.append(entry("burn"))
	if int(u.get("bleed_turns", 0)) > 0:
		out.append(entry("bleed", _turns(int(u.bleed_turns))))
	if int(u.get("rot_turns", 0)) > 0:
		var rot := entry("rot", _turns(int(u.rot_turns)))
		rot.desc = "Loses %d%% of its max HP at the start of its turn. If it dies cursed, the kill belongs to the Necromancer." % int(round(float(u.get("rot_pct", 0.1)) * 100.0))
		out.append(rot)
	if int(u.get("frozen_turns", 0)) > 0:
		out.append(entry("frozen", _turns(int(u.frozen_turns))))
	if int(u.get("concussed_turns", 0)) > 0:
		out.append(entry("concussed", _turns(int(u.concussed_turns))))
	if int(u.get("blind_turns", 0)) > 0:
		out.append(entry("blind", _turns(int(u.blind_turns))))
	if int(u.get("vulnerable_turns", 0)) > 0:
		out.append(entry("vulnerable", _turns(int(u.vulnerable_turns))))
	if u.get("stunned", false):
		out.append(entry("stunned"))
	if u.get("disarmed_tile", Vector2i(-1, -1)) != Vector2i(-1, -1):
		out.append(entry("disarmed"))
	if int(u.get("buffed_dmg_turns", 0)) > 0:
		out.append(entry("buffed", _turns(int(u.buffed_dmg_turns))))
	return out

# A party member's battle unit (Main.battle_allies / battle_downed_allies).
static func for_ally(u: Dictionary) -> Array:
	var out: Array = []
	if u.get("downed", false):
		out.append(entry("downed"))
	if int(u.get("stealth_turns", 0)) > 0:
		out.append(entry("stealth", _turns(int(u.stealth_turns))))
	if u.get("defending", false):
		out.append(entry("defending", "this round"))
	if int(u.get("buff_turns", 0)) > 0:
		out.append(entry("empowered", _turns(int(u.buff_turns))))
	if int(u.get("charm_turns", 0)) > 0:
		out.append(entry("charm", _turns(int(u.charm_turns))))
	if not u.get("charging", {}).is_empty():
		out.append(entry("charging"))
	if int(u.get("bloodrage_stacks", 0)) > 0:
		out.append(entry("bloodrage", "x%d" % int(u.bloodrage_stacks)))
	if int(u.get("skip_turns", 0)) > 0:
		out.append(entry("skip", _turns(int(u.skip_turns))))
	if u.get("disarmed_tile", Vector2i(-1, -1)) != Vector2i(-1, -1):
		out.append(entry("disarmed"))
	return out

# The hero. `h` is assembled by Main (it keeps the hero's states in several places): any of the keys below, absent = off.
# defending, taunting (bool); stealth, berserk, poison, bleed, blind, concussed, buff, potion_attack, potion_resilience,
# potion_energy, bloodrage, bloodboost, skip (turns / stacks); burning, disarmed, bloodcrash (bool); berserk_info ({damage, taken,
# move, rage}: what Berserk is worth now, for its description); rage_kills, rage_needed (the count towards the next Berserk).
static func for_hero(h: Dictionary) -> Array:
	var out: Array = []
	if h.get("defending", false):
		out.append(entry("defending", "this round"))
	if h.get("taunting", false):
		out.append(entry("taunting", "this round"))
	if int(h.get("stealth", 0)) > 0:
		out.append(entry("stealth", _turns(int(h.stealth))))
	if int(h.get("berserk", 0)) > 0:
		var rage := entry("berserk", _turns(int(h.berserk)))
		var info: Dictionary = h.get("berserk_info", {})
		if not info.is_empty():
			rage.desc = "+%d%% damage dealt, %d%% less damage taken and %d more tile of movement%s." % [int(info.damage), int(info.taken), int(info.move), (" (Rage %d makes all of it, and your turn speed, %d%% stronger)" % [int(info.rage), int(round(float(info.rage) * 5.0))]) if int(info.rage) > 0 else ""]
		out.append(rage)
	elif int(h.get("rage_kills", 0)) > 0:
		var building := entry("rage_building", "%d / %d" % [int(h.rage_kills), int(h.get("rage_needed", 5))])
		out.append(building)
	if int(h.get("buff", 0)) > 0:
		out.append(entry("empowered", _turns(int(h.buff))))
	if int(h.get("bloodrage", 0)) > 0:
		out.append(entry("bloodrage", "x%d" % int(h.bloodrage)))
	if int(h.get("bloodboost", 0)) > 0:
		out.append(entry("bloodboost", "x%d" % int(h.bloodboost)))
	if h.get("bloodcrash", false):
		out.append(entry("bloodcrash"))
	for key in ["potion_attack", "potion_resilience", "potion_energy"]:
		if int(h.get(key, 0)) > 0:
			out.append(entry(key, _turns(int(h[key]))))
	if int(h.get("poison", 0)) > 0:
		out.append(entry("poison", _turns(int(h.poison))))
	if h.get("burning", false):
		var burn := entry("burn")
		burn.desc = "Takes damage every turn and deals 25% less damage, until you step into water or drink something cleansing."
		out.append(burn)
	if int(h.get("bleed", 0)) > 0:
		out.append(entry("bleed", _turns(int(h.bleed))))
	if int(h.get("blind", 0)) > 0:
		var blind := entry("blind", _turns(int(h.blind)))
		blind.desc = "Your attacks usually miss, but any hit that lands is a guaranteed crit."
		out.append(blind)
	if int(h.get("concussed", 0)) > 0:
		var daze := entry("concussed", _turns(int(h.concussed)))
		daze.desc = "Dazed: each turn there is a 50% chance you hurt yourself."
		out.append(daze)
	if h.get("disarmed", false):
		var dis := entry("disarmed")
		dis.desc = "Your weapon is on the ground: you fight bare-handed until you reach the tile where it landed."
		out.append(dis)
	if int(h.get("skip", 0)) > 0:
		out.append(entry("skip", _turns(int(h.skip))))
	return out
