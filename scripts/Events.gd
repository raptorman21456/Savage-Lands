extends Node
class_name Events

# Flavor/metadata only -- effect logic lives in Main.gd (_apply_automatic_event/
# _resolve_event_choice), the same split SaveData.gd's UPGRADES uses between
# "what it's called and costs" and "what it actually does to the Player".
#
# "auto" events apply instantly with no player input (a message flash, see
# Main.gd:_maybe_trigger_event); everything else shows a 2-button choice
# modal (HUD.gd's event_panel) and waits for Yes/No.
#
# traveling_merchant's real description (naming the rolled weapon and its
# discounted price) is built dynamically in Main.gd, not stored here -- the
# text below is only the fallback/flavor line.
const EVENT_IDS := [
	"goblin_swarm", "elite_bounty", "warrior_joins",
	"traveling_merchant", "ancient_shrine", "wounded_traveler",
]

const EVENTS := {
	"goblin_swarm": {
		"name": "Goblin Swarm", "auto": true,
		"description": "A goblin warband has caught your scent! More of them are coming this wave -- but there's coin in it for you if you can weather it.",
	},
	"elite_bounty": {
		"name": "Elite Bounty", "auto": true,
		"description": "A notorious elite has been spotted nearby. Dangerous, but elites always carry richer spoils.",
	},
	"warrior_joins": {
		"name": "A Warrior Joins You", "auto": false,
		"description": "A traveling warrior offers to fight at your side for the rest of this journey.",
		"yes_label": "Recruit", "no_label": "Decline",
	},
	"traveling_merchant": {
		"name": "Traveling Merchant", "auto": false,
		"description": "A traveling merchant offers you a rare blade at a steep discount.",
		"yes_label": "Buy", "no_label": "Decline",
	},
	"ancient_shrine": {
		"name": "Ancient Shrine", "auto": false,
		"description": "A shrine hums with strange energy. Touching it is a gamble -- it might empower you, or it might not.",
		"yes_label": "Touch it", "no_label": "Leave it",
	},
	"wounded_traveler": {
		"name": "Wounded Traveler", "auto": false,
		"description": "A wounded traveler asks you to spare a healing item.",
		"yes_label": "Help", "no_label": "Ignore",
	},
}
