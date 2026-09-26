extends Node
class_name Potions

# Consumable, stackable -- buying one just adds its id to potion_queue (FIFO
# on use), no equip/owned concept. Every entry is a genuinely distinct pick,
# not a progression of "bigger heal" -- Health Potion is the plain heal (its
# heal_amount matches what a wild meat drop grants, see Player.gd:
# add_healing_item), the other 5 each do their own specific thing instead of
# (or alongside, for Cleansing) healing.
#
# effect: "" (Health -- plain heal only), "cleanse" (strips poison/burning/
# bleeding/concussion/blindness), "attack_buff" (temporary damage bonus),
# "resilience_buff" (temporary flat damage reduction), "energy_buff"
# (temporary +1 battle move range), or "restore_stamina" (instant, no
# duration). The three buffs last Main.gd's POTION_BUFF_TURNS once drunk --
# see _battle_player_item for dispatch and the turn-tick-down block
# (alongside Berserk/Stealth) for expiry.
#
# shop_description is a separate line from description -- the shopkeeper's
# own pitch, shown in HUD.gd's shop_keeper_box on hover, distinct from the
# plain mechanical description shown in the row's own tooltip.
static var TIERS := [
	{
		"id": "potion_health", "name": "Health Potion", "price": 15, "heal_amount": 20,
		"effect": "",
		"description": "Heals 20 HP.",
		"shop_description": "Drink up. Whatever's ailing you, this'll patch it.",
		"icon": "potion",
	},
	{
		"id": "potion_attack", "name": "Attack Potion", "price": 20, "heal_amount": 0,
		"effect": "attack_buff",
		"description": "No healing, but empowers your next 3 turns of attacks with +25% damage.",
		"shop_description": "Feel that? That's your arm asking permission to hit harder. Say yes.",
		"icon": "potion",
	},
	{
		"id": "potion_resilience", "name": "Resilience Potion", "price": 20, "heal_amount": 0,
		"effect": "resilience_buff",
		"description": "No healing, but shrugs off 20% of incoming damage for your next 3 turns.",
		"shop_description": "Won't stop a blade. Just stops it from mattering quite so much.",
		"icon": "potion",
	},
	{
		"id": "potion_energy", "name": "Energy Potion", "price": 15, "heal_amount": 0,
		"effect": "energy_buff",
		"description": "No healing, but grants an extra tile of movement in battle for your next 3 turns.",
		"shop_description": "Light on the feet, heavy on the results.",
		"icon": "potion",
	},
	{
		"id": "potion_stamina", "name": "Stamina Potion", "price": 12, "heal_amount": 0,
		"effect": "restore_stamina",
		"description": "No healing, but instantly refills your stamina to full.",
		"shop_description": "For when your arms give out before your enemies do.",
		"icon": "potion",
	},
	{
		"id": "potion_regular", "name": "Cleansing Potion", "price": 18, "heal_amount": 12,
		"effect": "cleanse",
		"description": "Heals 12 HP, and washes away poison, burning, bleeding, concussion, and blindness.",
		"shop_description": "Poison, fire, whatever's clinging to you -- this scrubs it right off.",
		"icon": "potion",
	},
]

static func get_tier(id: String) -> Dictionary:
	for t in TIERS:
		if t.id == id:
			return t
	return {}
